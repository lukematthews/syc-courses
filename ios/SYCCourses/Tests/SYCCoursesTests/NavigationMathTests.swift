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

    func testDurationFormattingIncludesHoursOnlyWhenNeeded() {
        XCTAssertEqual(AppFormatters.duration(3599), "59:59")
        XCTAssertEqual(AppFormatters.duration(3600), "1:00:00")
        XCTAssertEqual(AppFormatters.duration(3723), "1:02:03")
        XCTAssertEqual(AppFormatters.duration(nil), "--:--")
    }

    func testLineCrossingFindsSegmentAhead() {
        let result = NavigationMath.lineCrossing(
            fix: navigationFix(latitude: -0.001, longitude: 0.005, sogKnots: 6, cogDegrees: 0),
            lineStart: mark(latitude: 0, longitude: 0),
            lineEnd: mark(latitude: 0, longitude: 0.01)
        )

        XCTAssertEqual(result.status, .approachingLine)
        XCTAssertEqual(result.distanceMeters ?? 0, 111, accuracy: 2)
        XCTAssertEqual(result.timeToLine ?? 0, 36, accuracy: 2)
    }

    func testLineCrossingRejectsOutsideSegment() {
        let result = NavigationMath.lineCrossing(
            fix: navigationFix(latitude: -0.001, longitude: 0.02, sogKnots: 6, cogDegrees: 0),
            lineStart: mark(latitude: 0, longitude: 0),
            lineEnd: mark(latitude: 0, longitude: 0.01)
        )

        XCTAssertEqual(result.status, .crossingOutsideSegment)
        XCTAssertNil(result.timeToLine)
    }

    func testLineCrossingReportsMissingCourseAndSpeed() {
        let lineStart = mark(latitude: 0, longitude: 0)
        let lineEnd = mark(latitude: 0, longitude: 0.01)

        XCTAssertEqual(
            NavigationMath.lineCrossing(
                fix: navigationFix(latitude: -0.001, longitude: 0.005, sogKnots: 6, cogDegrees: nil),
                lineStart: lineStart,
                lineEnd: lineEnd
            ).status,
            .insufficientData(.noCOG)
        )

        XCTAssertEqual(
            NavigationMath.lineCrossing(
                fix: navigationFix(latitude: -0.001, longitude: 0.005, sogKnots: 0.1, cogDegrees: 0),
                lineStart: lineStart,
                lineEnd: lineEnd
            ).status,
            .insufficientData(.noSOG)
        )
    }

    private func mark(latitude: Double, longitude: Double) -> Mark {
        Mark(
            id: UUID().uuidString,
            name: "Test",
            aliases: [],
            latitude: latitude,
            longitude: longitude,
            description: nil,
            coordinatesStatus: "verified"
        )
    }

    private func navigationFix(latitude: Double, longitude: Double, sogKnots: Double?, cogDegrees: Double?) -> NavigationFix {
        NavigationFix(
            latitude: latitude,
            longitude: longitude,
            sogKnots: sogKnots,
            cogDegrees: cogDegrees,
            headingDegrees: nil,
            timestamp: Date(timeIntervalSinceReferenceDate: 0),
            source: .iPhoneGPS,
            horizontalAccuracyMeters: 3,
            hdop: nil,
            validFix: true
        )
    }
}
#endif
