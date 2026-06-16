#if canImport(XCTest)
@testable import SYCCourses
import XCTest

final class NavigationMathTests: XCTestCase {
    func testNormalizeDegrees() {
        XCTAssertEqual(NavigationMath.normalizeDegrees(370), 10, accuracy: 0.0001)
        XCTAssertEqual(NavigationMath.normalizeDegrees(-10), 350, accuracy: 0.0001)
        XCTAssertEqual(NavigationMath.normalizeDegrees(720), 0, accuracy: 0.0001)
    }

    func testBearingBetweenSYCMarks() {
        let bearing = NavigationMath.bearingTrue(
            fromLatitude: -37.946833,
            fromLongitude: 144.99,
            toLatitude: -37.963333,
            toLongitude: 144.9815
        )
        XCTAssertEqual(bearing, 202.1, accuracy: 0.5)
    }

    func testDistanceBetweenSYCMarks() {
        let distance = NavigationMath.distanceNm(
            fromLatitude: -37.946833,
            fromLongitude: 144.99,
            toLatitude: -37.963333,
            toLongitude: 144.9815
        )
        XCTAssertEqual(distance, 1.07, accuracy: 0.03)
    }

    func testMagneticVariationSubtractsEastVariation() {
        XCTAssertEqual(NavigationMath.magneticBearing(trueBearing: 10, variationDegrees: 12), 358, accuracy: 0.0001)
    }

    func testTimeToMark() {
        XCTAssertEqual(NavigationMath.timeToMark(distanceNm: 1.5, speedKnots: 6), 900 as TimeInterval?)
        XCTAssertNil(NavigationMath.timeToMark(distanceNm: 1.5, speedKnots: 0))
    }

    func testTimeToBurn() {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let start = now.addingTimeInterval(600)
        let snapshot = NavigationMath.timeToBurn(startTime: start, now: now, timeToMark: 420)
        XCTAssertEqual(snapshot.timeToStart, 600, accuracy: 0.0001)
        XCTAssertEqual(snapshot.timeToBurn, 180 as TimeInterval?)
    }
}
#endif
