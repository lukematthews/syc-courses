import Combine
import Foundation

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
    private var subscriptions: Set<AnyCancellable> = []
    private var lastPublishedSnapshot: CourseNavigationWidgetSnapshot?
    private var isConfigured = false

    #if canImport(ActivityKit) && os(iOS)
    private var liveActivity: Activity<CourseNavigationActivityAttributes>?
    #endif

    func configure(activeRaceStore: ActiveRaceStore, locationService: LocationService) {
        guard !isConfigured else { return }
        isConfigured = true
        self.activeRaceStore = activeRaceStore
        self.locationService = locationService

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

        synchronize()
    }

    private func synchronize() {
        guard let activeRaceStore, let locationService else { return }
        guard let course = activeRaceStore.activeCourse,
              let mark = activeRaceStore.activeMark,
              let legIndex = activeRaceStore.activeLegIndex
        else {
            locationService.stopActiveUpdates(for: .activeCourse)
            CourseNavigationWidgetStore.save(nil)
            reloadWidgets()
            endLiveActivity()
            lastPublishedSnapshot = nil
            return
        }

        locationService.startActiveUpdates(for: .activeCourse)
        let bearingSnapshot = locationService.snapshot(to: mark)
        let snapshot = CourseNavigationWidgetSnapshot(
            courseID: course.id,
            courseNumber: course.courseNumber,
            clubName: CourseDataLoader.bundledPack.shortName,
            markName: mark.name,
            roundingSide: activeRaceStore.activeRoundingSide ?? "",
            legIndex: legIndex,
            totalLegs: activeRaceStore.courseMarks.count,
            bearingTrue: bearingSnapshot?.bearingTrue,
            distanceNm: bearingSnapshot?.distanceNm,
            horizontalAccuracyMeters: bearingSnapshot?.horizontalAccuracyMeters,
            positionTimestamp: bearingSnapshot?.timestamp,
            updatedAt: Date()
        )

        CourseNavigationWidgetStore.save(snapshot)
        publish(snapshot)
    }

    private func publish(_ snapshot: CourseNavigationWidgetSnapshot) {
        let courseOrLegChanged = lastPublishedSnapshot?.courseID != snapshot.courseID
            || lastPublishedSnapshot?.legIndex != snapshot.legIndex
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
            distanceNm: snapshot.distanceNm,
            horizontalAccuracyMeters: snapshot.horizontalAccuracyMeters,
            positionTimestamp: snapshot.positionTimestamp
        )
    }
}
#endif
