import Combine
import Foundation
import OSLog

extension Notification.Name {
    static let navigationBearingDisplayReferenceDidChange = Notification.Name(
        "navigationBearingDisplayReferenceDidChange"
    )
}

#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

#if canImport(WidgetKit) && os(iOS)
import WidgetKit
#endif

@MainActor
final class CourseNavigationSurfaceCoordinator: ObservableObject {
    private weak var activeRaceStore: ActiveRaceStore?
    private weak var locationService: LocationService?
    private weak var navigationDataService: NavigationDataService?
    private weak var navigationOutputService: NavigationOutputService?
    private var subscriptions: Set<AnyCancellable> = []
    private var lastPublishedSnapshot: CourseNavigationWidgetSnapshot?
    private var lastOutputAt: Date?
    private var lastOutputCourseID: String?
    private var lastOutputLegIndex: Int?
    private var outputTask: Task<Void, Never>?
    private var isConfigured = false
    private var hasSynchronizedInactiveCourse = false
    private let logger = Logger(subsystem: "SYCCourses", category: "ActiveCourseOutput")

    #if canImport(ActivityKit) && os(iOS)
    private var liveActivity: Activity<CourseNavigationActivityAttributes>?
    #endif

    func configure(
        activeRaceStore: ActiveRaceStore,
        locationService: LocationService,
        navigationDataService: NavigationDataService,
        navigationOutputService: NavigationOutputService
    ) {
        guard !isConfigured else { return }
        isConfigured = true
        self.activeRaceStore = activeRaceStore
        self.locationService = locationService
        self.navigationDataService = navigationDataService
        self.navigationOutputService = navigationOutputService

        Publishers.CombineLatest3(
            activeRaceStore.$activeCourseID,
            activeRaceStore.$activeLegIndex,
            locationService.$location
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _, _ in
            self?.synchronize()
        }
        .store(in: &subscriptions)

        navigationDataService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.synchronize()
            }
        .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: .navigationBearingDisplayReferenceDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.synchronize()
            }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: .quickBearingOutputDidEnd)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.synchronize()
            }
            .store(in: &subscriptions)

        synchronize()
    }

    private func synchronize() {
        guard let activeRaceStore, let locationService, let navigationDataService else { return }
        guard let course = activeRaceStore.activeCourse,
              let mark = activeRaceStore.activeMark,
              let legIndex = activeRaceStore.activeLegIndex
        else {
            guard !hasSynchronizedInactiveCourse else { return }
            hasSynchronizedInactiveCourse = true
            let shouldClearOutput = lastOutputCourseID != nil
            locationService.stopActiveUpdates(for: .activeCourse)
            navigationDataService.stopNavigationInput(for: .activeCourse)
            CourseNavigationWidgetStore.save(nil)
            reloadWidgets()
            endLiveActivity()
            lastPublishedSnapshot = nil
            lastOutputAt = nil
            lastOutputCourseID = nil
            lastOutputLegIndex = nil
            outputTask?.cancel()
            if shouldClearOutput,
               let navigationOutputService,
               !navigationOutputService.isQuickBearingOutputActive {
                outputTask = Task { @MainActor [weak navigationOutputService] in
                    await navigationOutputService?.clearActiveWaypoint()
                }
            } else {
                outputTask = nil
            }
            return
        }

        hasSynchronizedInactiveCourse = false

        locationService.startActiveUpdates(for: .activeCourse)
        navigationDataService.startNavigationInput(for: .activeCourse)
        let activeFix = navigationDataService.activeFix(iPhoneFix: locationService.navigationFix)
        let bearingSnapshot = navigationDataService.snapshot(to: mark, iPhoneFix: locationService.navigationFix)
        let isUsingFallback = navigationDataService.actisenseConfig.isEnabled
            && activeFix?.source == .iPhoneGPS
        let snapshot = CourseNavigationWidgetSnapshot(
            courseID: course.id,
            courseNumber: course.courseNumber,
            clubName: CourseDataLoader.bundledPack.shortName,
            markName: mark.name,
            roundingSide: activeRaceStore.activeRoundingSide ?? "",
            legIndex: legIndex,
            totalLegs: activeRaceStore.courseMarks.count,
            bearingTrue: bearingSnapshot?.bearingTrue,
            bearingReference: UserDefaults.standard.string(forKey: "navigationBearingDisplayReference")
                ?? NavigationBearingDisplayReference.trueNorth.rawValue,
            magneticVariationDegrees: NavigationMath.magneticVariationDegrees,
            positionSource: activeFix?.source.label,
            isUsingFallbackPosition: isUsingFallback,
            distanceNm: bearingSnapshot?.distanceNm,
            horizontalAccuracyMeters: bearingSnapshot?.horizontalAccuracyMeters,
            positionTimestamp: bearingSnapshot?.timestamp,
            updatedAt: Date()
        )

        CourseNavigationWidgetStore.save(snapshot)
        publish(snapshot)
        transmitActiveWaypoint(course: course, mark: mark, legIndex: legIndex)
    }

    private func transmitActiveWaypoint(course: Course, mark: Mark, legIndex: Int, now: Date = Date()) {
        guard let locationService, let navigationDataService, let navigationOutputService else {
            logger.error("Active Course output skipped: navigation services are unavailable")
            return
        }
        guard !navigationOutputService.isQuickBearingOutputActive else {
            logger.debug("Active Course output paused while Quick Bearing owns instrument output")
            return
        }
        guard navigationOutputService.settings.target != .disabled else {
            logger.debug("Active Course output skipped: output is disabled")
            return
        }
        guard navigationOutputService.settings.isConfigured else {
            logger.error("Active Course output skipped: gateway settings are incomplete")
            return
        }

        let courseOrLegChanged = lastOutputCourseID != course.id || lastOutputLegIndex != legIndex
        if !courseOrLegChanged,
           let lastOutputAt,
           now.timeIntervalSince(lastOutputAt) < 1 {
            logger.debug("Active Course output throttled: last update was less than one second ago")
            return
        }

        guard let bearingSnapshot = navigationDataService.snapshot(
            to: mark,
            iPhoneFix: locationService.navigationFix,
            now: now
        ) else {
            logger.error("Active Course output skipped: no usable navigation fix for mark \(mark.name, privacy: .public)")
            return
        }

        let waypoint = NavigationWaypointState(
            courseNumber: course.courseNumber,
            originName: "SYC",
            waypointName: mark.name,
            waypointID: mark.id,
            latitude: mark.latitude,
            longitude: mark.longitude,
            bearingTrue: bearingSnapshot.bearingTrue,
            magneticVariationDegrees: NavigationMath.magneticVariationDegrees,
            distanceNm: bearingSnapshot.distanceNm,
            speedOverGroundKnots: bearingSnapshot.speedOverGroundKnots,
            timestamp: bearingSnapshot.timestamp
        )

        lastOutputAt = now
        lastOutputCourseID = course.id
        lastOutputLegIndex = legIndex
        outputTask?.cancel()
        outputTask = Task { @MainActor [weak self, weak navigationOutputService] in
            guard let self, let navigationOutputService else { return }
            if !navigationOutputService.isConnected {
                guard !navigationOutputService.isManuallyDisconnected else {
                    self.logger.debug("Active Course output remains disconnected by user request")
                    return
                }
                guard navigationOutputService.settings.autoConnect else {
                    self.logger.error("Active Course output skipped: gateway is disconnected and auto-connect is off")
                    return
                }
                self.logger.info("Active Course output connecting to configured gateway")
                await navigationOutputService.connect()
            }
            guard navigationOutputService.isConnected else {
                self.logger.error("Active Course output skipped: gateway did not reach connected state")
                return
            }
            self.logger.info(
                "Active Course sending course \(course.courseNumber) leg \(legIndex + 1) to \(mark.name, privacy: .public): BTW \(bearingSnapshot.bearingTrue, format: .fixed(precision: 1)) DTW \(bearingSnapshot.distanceNm, format: .fixed(precision: 3)) nm"
            )
            await navigationOutputService.sendActiveWaypoint(waypoint)
        }
    }

    private func publish(_ snapshot: CourseNavigationWidgetSnapshot) {
        let courseOrLegChanged = lastPublishedSnapshot?.courseID != snapshot.courseID
            || lastPublishedSnapshot?.legIndex != snapshot.legIndex
            || lastPublishedSnapshot?.bearingReference != snapshot.bearingReference
        let elapsed = snapshot.updatedAt.timeIntervalSince(lastPublishedSnapshot?.updatedAt ?? .distantPast)
        let bearingChanged = angularDifference(lastPublishedSnapshot?.bearingTrue, snapshot.bearingTrue) >= 2
        let distanceChanged = abs((lastPublishedSnapshot?.distanceNm ?? snapshot.distanceNm ?? 0) - (snapshot.distanceNm ?? 0)) >= 0.01

        guard courseOrLegChanged || elapsed >= 5 || bearingChanged || distanceChanged else { return }
        lastPublishedSnapshot = snapshot
        reloadWidgets()
        updateLiveActivity(with: snapshot)
    }

    private func angularDifference(_ lhs: Double?, _ rhs: Double?) -> Double {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil ? 0 : 360 }
        let difference = abs(lhs - rhs).truncatingRemainder(dividingBy: 360)
        return min(difference, 360 - difference)
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit) && os(iOS)
        WidgetCenter.shared.reloadTimelines(ofKind: "CourseNavigationWidget")
        #endif
    }

    #if canImport(ActivityKit) && os(iOS)
    private func updateLiveActivity(with snapshot: CourseNavigationWidgetSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = CourseNavigationActivityAttributes.ContentState(snapshot: snapshot)
        let staleDate = (snapshot.positionTimestamp ?? Date()).addingTimeInterval(30)
        let content = ActivityContent(state: state, staleDate: staleDate, relevanceScore: 100)

        if let liveActivity, liveActivity.attributes.courseID != snapshot.courseID {
            Task {
                await liveActivity.end(nil, dismissalPolicy: .immediate)
            }
            self.liveActivity = nil
        }

        if liveActivity == nil {
            liveActivity = Activity<CourseNavigationActivityAttributes>.activities.first {
                $0.attributes.courseID == snapshot.courseID
            }
        }

        if let liveActivity {
            Task {
                await liveActivity.update(content)
            }
            return
        }

        for activity in Activity<CourseNavigationActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        let attributes = CourseNavigationActivityAttributes(
            courseID: snapshot.courseID,
            clubName: snapshot.clubName
        )
        liveActivity = try? Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }

    private func endLiveActivity() {
        let activities = Activity<CourseNavigationActivityAttributes>.activities
        liveActivity = nil
        for activity in activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    #else
    private func updateLiveActivity(with snapshot: CourseNavigationWidgetSnapshot) {}
    private func endLiveActivity() {}
    #endif
}

#if canImport(ActivityKit) && os(iOS)
private extension CourseNavigationActivityAttributes.ContentState {
    init(snapshot: CourseNavigationWidgetSnapshot) {
        self.init(
            courseNumber: snapshot.courseNumber,
            markName: snapshot.markName,
            roundingSide: snapshot.roundingSide,
            legIndex: snapshot.legIndex,
            totalLegs: snapshot.totalLegs,
            bearingTrue: snapshot.bearingTrue,
            bearingReference: snapshot.bearingReference,
            magneticVariationDegrees: snapshot.magneticVariationDegrees,
            positionSource: snapshot.positionSource,
            isUsingFallbackPosition: snapshot.isUsingFallbackPosition,
            distanceNm: snapshot.distanceNm,
            horizontalAccuracyMeters: snapshot.horizontalAccuracyMeters,
            positionTimestamp: snapshot.positionTimestamp
        )
    }
}
#endif
