import XCTest
@testable import SYCCourses

final class ActiveRaceStoreTests: XCTestCase {
    func testBundledPackProvidesNamespacedCourseIdentityAndNavigationDefaults() throws {
        let course = try XCTUnwrap(CourseDataLoader.fixedCourses().first)

        XCTAssertEqual(course.packId, CourseDataLoader.bundledPack.packId)
        XCTAssertEqual(course.kind, .fixed)
        XCTAssertEqual(course.id, "\(course.packId)/fixed/course-\(course.courseNumber)")
        XCTAssertEqual(CourseDataLoader.startLineMarks().map(\.id), ["syc-tower", "syc-4"])
    }

    func testCourseBuilderStartsAtBundledPackLineAndFindsNavigationMarks() throws {
        let course = try XCTUnwrap(
            CourseDataLoader.fixedCourses().first { ActiveRaceCourseBuilder.navigationMarks(for: $0).count >= 2 }
        )
        let lineMarks = ActiveRaceCourseBuilder.courseLineMarks(for: course)
        let navigationMarks = ActiveRaceCourseBuilder.navigationMarks(for: course)

        XCTAssertEqual(lineMarks.first?.name, "SYC 4")
        XCTAssertFalse(navigationMarks.isEmpty)
        XCTAssertNotEqual(navigationMarks.first?.name.normalizedCourseMarkName, "start")
    }

    func testActiveRaceStoreAdvancesAndRetreatsMark() throws {
        let suiteName = "ActiveRaceStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let course = try XCTUnwrap(CourseDataLoader.fixedCourses().first { $0.courseNumber == 1 })
        let store = ActiveRaceStore(defaults: defaults)

        store.setActiveCourse(course)
        let firstMark = try XCTUnwrap(store.activeMark)

        store.advanceMark()
        let secondMark = try XCTUnwrap(store.activeMark)

        XCTAssertNotEqual(firstMark.id, secondMark.id)

        store.retreatMark()
        XCTAssertEqual(store.activeMark?.id, firstMark.id)
    }

    func testActiveRaceStoreProgressesThroughRepeatedMarksByLeg() throws {
        let suiteName = "ActiveRaceStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let course = try XCTUnwrap(
            CourseDataLoader.fixedCourses().first { course in
                let markIDs = ActiveRaceCourseBuilder.navigationMarks(for: course).map(\.id)
                return Set(markIDs).count < markIDs.count
            }
        )
        let store = ActiveRaceStore(defaults: defaults)

        store.setActiveCourse(course)
        for expectedIndex in store.courseMarks.indices {
            XCTAssertEqual(store.activeLegIndex, expectedIndex)
            if expectedIndex < store.courseMarks.count - 1 {
                store.advanceMark()
            }
        }

        XCTAssertEqual(store.activeLegIndex, store.courseMarks.count - 1)
    }

    func testStoppingClearsActiveCourseAndPersistedNavigationState() throws {
        let suiteName = "ActiveRaceStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let course = try XCTUnwrap(CourseDataLoader.fixedCourses().first)
        let store = ActiveRaceStore(defaults: defaults)

        store.setActiveCourse(course)
        ActiveCourseEndAction.stop.perform(on: store)

        XCTAssertNil(store.activeCourse)
        XCTAssertNil(store.activeCourseID)
        XCTAssertNil(store.activeMarkID)
        XCTAssertNil(store.activeLegIndex)
        XCTAssertNil(defaults.string(forKey: "activeRaceCourseID"))
        XCTAssertNil(defaults.string(forKey: "activeRaceMarkID"))
        XCTAssertNil(defaults.object(forKey: "activeRaceLegIndex"))
    }

    func testFinishingFinalMarkUsesSameStopBehaviour() throws {
        let suiteName = "ActiveRaceStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let course = try XCTUnwrap(CourseDataLoader.fixedCourses().first)
        let store = ActiveRaceStore(defaults: defaults)

        store.setActiveCourse(course)
        while store.activeMarkIndex != store.courseMarks.count - 1 {
            store.advanceMark()
        }
        ActiveCourseEndAction.finish.perform(on: store)

        XCTAssertFalse(store.isCourseActive)
        XCTAssertNil(store.activeCourseID)
    }

    @MainActor
    func testCoordinatorReleasesActiveCourseLocationOwnerAfterStop() async throws {
        let suiteName = "ActiveRaceStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let course = try XCTUnwrap(CourseDataLoader.fixedCourses().first)
        let store = ActiveRaceStore(defaults: defaults)
        let locationService = LocationService()
        let navigationDataService = NavigationDataService(defaults: defaults)
        let navigationOutputService = NavigationOutputService(defaults: defaults)
        let coordinator = CourseNavigationSurfaceCoordinator()

        coordinator.configure(
            activeRaceStore: store,
            locationService: locationService,
            navigationDataService: navigationDataService,
            navigationOutputService: navigationOutputService
        )
        store.setActiveCourse(course)
        try await waitUntil {
            locationService.isUpdating(for: .activeCourse)
        }

        ActiveCourseEndAction.stop.perform(on: store)
        try await waitUntil {
            !locationService.isUpdating(for: .activeCourse)
        }

        XCTAssertFalse(locationService.isUpdating(for: .activeCourse))
    }

    func testWidgetStoreDerivesSharedGroupFromAppAndExtensionBundleIDs() {
        XCTAssertEqual(
            CourseNavigationWidgetStore.appGroupIdentifier(bundleIdentifier: "au.com.syc.courses"),
            "group.au.com.syc.courses"
        )
        XCTAssertEqual(
            CourseNavigationWidgetStore.appGroupIdentifier(bundleIdentifier: "au.com.syc.courses.navigation-widget"),
            "group.au.com.syc.courses"
        )
    }

    func testActiveRaceStoreMigratesLegacyCourseNumber() throws {
        let suiteName = "ActiveRaceStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(1, forKey: "activeRaceCourseNumber")

        let store = ActiveRaceStore(defaults: defaults)

        XCTAssertEqual(store.activeCourse?.courseNumber, 1)
        XCTAssertEqual(defaults.string(forKey: "activeRaceCourseID"), store.activeCourse?.id)
        XCTAssertNil(defaults.object(forKey: "activeRaceCourseNumber"))
    }

    func testRecentCoursesMigrateLegacyNumbersToCompoundIDs() throws {
        let suiteName = "RecentCoursesStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set([1, 80], forKey: "recentCourseNumbers")

        let store = RecentCoursesStore(defaults: defaults)

        XCTAssertEqual(store.recentCourseIDs.count, 2)
        XCTAssertTrue(store.recentCourseIDs[0].hasSuffix("/fixed/course-1"))
        XCTAssertTrue(store.recentCourseIDs[1].hasSuffix("/laid/course-80"))
        XCTAssertNil(defaults.object(forKey: "recentCourseNumbers"))
    }

    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            if clock.now >= deadline {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
