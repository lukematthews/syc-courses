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

    func testCourseBuilderStartsAtSYC4AndFindsNavigationMarks() throws {
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
}
