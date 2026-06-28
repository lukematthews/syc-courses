import CoreLocation
import XCTest
@testable import SYCCourses

final class RaceTrackMathTests: XCTestCase {
    func testDurationUsesFirstAndLastPoint() {
        let start = Date(timeIntervalSince1970: 100)
        let points = [
            RaceTrackPoint(latitude: -37.9, longitude: 145.0, timestamp: start),
            RaceTrackPoint(latitude: -37.8, longitude: 145.1, timestamp: start.addingTimeInterval(45))
        ]

        XCTAssertEqual(RaceTrackMath.duration(for: points), 45)
    }

    func testCoordinateInterpolatesForScrubbedTime() throws {
        let start = Date(timeIntervalSince1970: 100)
        let points = [
            RaceTrackPoint(latitude: -38.0, longitude: 145.0, timestamp: start),
            RaceTrackPoint(latitude: -37.0, longitude: 146.0, timestamp: start.addingTimeInterval(60))
        ]

        let coordinate = try XCTUnwrap(RaceTrackMath.coordinate(at: 15, in: points))

        XCTAssertEqual(coordinate.latitude, -37.75, accuracy: 0.0001)
        XCTAssertEqual(coordinate.longitude, 145.25, accuracy: 0.0001)
    }

    func testCoordinateClampsAfterLastPoint() throws {
        let start = Date(timeIntervalSince1970: 100)
        let points = [
            RaceTrackPoint(latitude: -38.0, longitude: 145.0, timestamp: start),
            RaceTrackPoint(latitude: -37.0, longitude: 146.0, timestamp: start.addingTimeInterval(60))
        ]

        let coordinate = try XCTUnwrap(RaceTrackMath.coordinate(at: 90, in: points))

        XCTAssertEqual(coordinate.latitude, -37.0, accuracy: 0.0001)
        XCTAssertEqual(coordinate.longitude, 146.0, accuracy: 0.0001)
    }
}
