import XCTest
@testable import SYCCourses

final class ActiveRaceStoreTests: XCTestCase {
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
}
