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

    func testBoatReferencePointProjectsBowNorth() {
        let result = NavigationMath.calculateBoatReferencePoint(
            gpsPosition: LatLon(latitude: 0, longitude: 0),
            cogDegrees: 0,
            headingDegrees: nil,
            geometry: BoatGeometrySettings(bowOffsetMeters: 10, gpsOffsetStarboardMeters: 0, useBowOffsetForLineAssist: true)
        )

        XCTAssertEqual(result.referencePoint, .bow)
        XCTAssertTrue(result.isBowOffsetApplied)
        XCTAssertGreaterThan(result.position.latitude, 0)
        XCTAssertEqual(result.position.longitude, 0, accuracy: 0.000001)
    }

    func testBoatReferencePointProjectsBowEast() {
        let result = NavigationMath.calculateBoatReferencePoint(
            gpsPosition: LatLon(latitude: 0, longitude: 0),
            cogDegrees: 90,
            headingDegrees: nil,
            geometry: BoatGeometrySettings(bowOffsetMeters: 10, gpsOffsetStarboardMeters: 0, useBowOffsetForLineAssist: true)
        )

        XCTAssertEqual(result.referencePoint, .bow)
        XCTAssertGreaterThan(result.position.longitude, 0)
        XCTAssertEqual(result.position.latitude, 0, accuracy: 0.000001)
    }

    func testBoatReferencePointDisabledUsesGPS() {
        let position = LatLon(latitude: -37.9, longitude: 145)
        let result = NavigationMath.calculateBoatReferencePoint(
            gpsPosition: position,
            cogDegrees: 0,
            headingDegrees: 0,
            geometry: BoatGeometrySettings(bowOffsetMeters: 10, gpsOffsetStarboardMeters: 0, useBowOffsetForLineAssist: false)
        )

        XCTAssertEqual(result.position, position)
        XCTAssertEqual(result.referencePoint, .gps)
        XCTAssertFalse(result.isBowOffsetApplied)
        XCTAssertFalse(result.isDegraded)
        XCTAssertEqual(result.degradedReason, .disabled)
    }

    func testBoatReferencePointDefaultCOGDoesNotRequireHeading() {
        let result = NavigationMath.calculateBoatReferencePoint(
            gpsPosition: LatLon(latitude: 0, longitude: 0),
            cogDegrees: 0,
            headingDegrees: nil,
            geometry: BoatGeometrySettings(bowOffsetMeters: 10, gpsOffsetStarboardMeters: 0, useBowOffsetForLineAssist: true)
        )

        XCTAssertEqual(result.referencePoint, .bow)
        XCTAssertTrue(result.isBowOffsetApplied)
        XCTAssertFalse(result.isDegraded)
        XCTAssertGreaterThan(result.position.latitude, 0)
    }

    func testBoatReferencePointAdvancedHeadingModeFallsBackWhenHeadingIsMissing() {
        let position = LatLon(latitude: -37.9, longitude: 145)
        let result = NavigationMath.calculateBoatReferencePoint(
            gpsPosition: position,
            cogDegrees: 0,
            headingDegrees: nil,
            geometry: BoatGeometrySettings(
                bowOffsetMeters: 10,
                gpsOffsetStarboardMeters: 0,
                useBowOffsetForLineAssist: true,
                referenceBearingSource: .heading
            )
        )

        XCTAssertEqual(result.position, position)
        XCTAssertEqual(result.referencePoint, .gps)
        XCTAssertFalse(result.isBowOffsetApplied)
        XCTAssertTrue(result.isDegraded)
        XCTAssertEqual(result.degradedReason, .missingHeading)
    }

    func testBoatReferencePointZeroBowOffsetFallsBackToGPS() {
        let position = LatLon(latitude: -37.9, longitude: 145)
        let result = NavigationMath.calculateBoatReferencePoint(
            gpsPosition: position,
            cogDegrees: 0,
            headingDegrees: 0,
            geometry: BoatGeometrySettings(bowOffsetMeters: 0, gpsOffsetStarboardMeters: 0, useBowOffsetForLineAssist: true)
        )

        XCTAssertEqual(result.position, position)
        XCTAssertEqual(result.referencePoint, .gps)
        XCTAssertTrue(result.isDegraded)
        XCTAssertEqual(result.degradedReason, .missingGeometry)
    }

    func testBoatReferencePointCorrectsStarboardSidewaysOffsetToPort() {
        let result = NavigationMath.calculateBoatReferencePoint(
            gpsPosition: LatLon(latitude: 0, longitude: 0),
            cogDegrees: 0,
            headingDegrees: nil,
            geometry: BoatGeometrySettings(bowOffsetMeters: 10, gpsOffsetStarboardMeters: 2, useBowOffsetForLineAssist: true)
        )

        XCTAssertGreaterThan(result.position.latitude, 0)
        XCTAssertLessThan(result.position.longitude, 0)
    }

    func testBoatReferencePointCorrectsPortSidewaysOffsetToStarboard() {
        let result = NavigationMath.calculateBoatReferencePoint(
            gpsPosition: LatLon(latitude: 0, longitude: 0),
            cogDegrees: 0,
            headingDegrees: nil,
            geometry: BoatGeometrySettings(bowOffsetMeters: 10, gpsOffsetStarboardMeters: -2, useBowOffsetForLineAssist: true)
        )

        XCTAssertGreaterThan(result.position.latitude, 0)
        XCTAssertGreaterThan(result.position.longitude, 0)
    }

    func testBowCorrectionReducesPerpendicularTimeToLine() {
        let lineStart = mark(latitude: 0, longitude: -0.001)
        let lineEnd = mark(latitude: 0, longitude: 0.001)
        let gps = navigationFix(latitude: -100 / 111_320, longitude: 0, sogKnots: 5, cogDegrees: 0, headingDegrees: 0)
        let gpsResult = NavigationMath.lineCrossing(fix: gps, lineStart: lineStart, lineEnd: lineEnd)
        let bowResult = NavigationMath.lineCrossing(
            fix: gps,
            lineStart: lineStart,
            lineEnd: lineEnd,
            geometry: BoatGeometrySettings(bowOffsetMeters: 10, gpsOffsetStarboardMeters: 0, useBowOffsetForLineAssist: true)
        )

        XCTAssertEqual(bowResult.referencePoint, .bow)
        XCTAssertTrue(bowResult.isBowOffsetApplied)
        XCTAssertEqual((gpsResult.timeToLine ?? 0) - (bowResult.timeToLine ?? 0), 10 / knotsToMetersPerSecond(5), accuracy: 0.4)
        XCTAssertEqual(bowResult.bowGainToLineMeters ?? 0, 10, accuracy: 0.4)
    }

    func testBowCorrectionDoesNotReduceParallelDistance() {
        let lineStart = mark(latitude: 0, longitude: -0.001)
        let lineEnd = mark(latitude: 0, longitude: 0.001)
        let gps = navigationFix(latitude: -100 / 111_320, longitude: 0, sogKnots: 5, cogDegrees: 90, headingDegrees: 90)
        let bowResult = NavigationMath.lineCrossing(
            fix: gps,
            lineStart: lineStart,
            lineEnd: lineEnd,
            geometry: BoatGeometrySettings(bowOffsetMeters: 10, gpsOffsetStarboardMeters: 0, useBowOffsetForLineAssist: true)
        )

        XCTAssertEqual(bowResult.status, .parallel)
        XCTAssertEqual(bowResult.gpsDistanceToLineMeters ?? 0, bowResult.bowDistanceToLineMeters ?? -1, accuracy: 0.2)
        XCTAssertEqual(bowResult.bowGainToLineMeters ?? 0, 0, accuracy: 0.2)
    }

    func testBowCorrectionPartiallyReducesDistanceAtFortyFiveDegrees() {
        let lineStart = mark(latitude: 0, longitude: -0.001)
        let lineEnd = mark(latitude: 0, longitude: 0.001)
        let gps = navigationFix(latitude: -100 / 111_320, longitude: 0, sogKnots: 5, cogDegrees: 45, headingDegrees: nil)
        let bowResult = NavigationMath.lineCrossing(
            fix: gps,
            lineStart: lineStart,
            lineEnd: lineEnd,
            geometry: BoatGeometrySettings(bowOffsetMeters: 10, gpsOffsetStarboardMeters: 0, useBowOffsetForLineAssist: true)
        )

        XCTAssertEqual(bowResult.bowGainToLineMeters ?? 0, 10 * cos(.pi / 4), accuracy: 0.4)
    }

    func testDefaultBowPositionUsesCOGWhenHeadingDiffers() {
        let lineStart = mark(latitude: 0, longitude: -0.001)
        let lineEnd = mark(latitude: 0, longitude: 0.001)
        let gps = navigationFix(latitude: -100 / 111_320, longitude: 0, sogKnots: 5, cogDegrees: 90, headingDegrees: 0)
        let bowResult = NavigationMath.lineCrossing(
            fix: gps,
            lineStart: lineStart,
            lineEnd: lineEnd,
            geometry: BoatGeometrySettings(bowOffsetMeters: 10, gpsOffsetStarboardMeters: 0, useBowOffsetForLineAssist: true)
        )

        XCTAssertEqual(bowResult.status, .parallel)
        XCTAssertNil(bowResult.timeToLine)
        XCTAssertEqual(bowResult.bowGainToLineMeters ?? 0, 0, accuracy: 0.4)
    }

    func testAdvancedHeadingBowPositionUsesHeadingButTTLUsesCOG() {
        let lineStart = mark(latitude: 0, longitude: -0.001)
        let lineEnd = mark(latitude: 0, longitude: 0.001)
        let gps = navigationFix(latitude: -100 / 111_320, longitude: 0, sogKnots: 5, cogDegrees: 90, headingDegrees: 0)
        let bowResult = NavigationMath.lineCrossing(
            fix: gps,
            lineStart: lineStart,
            lineEnd: lineEnd,
            geometry: BoatGeometrySettings(
                bowOffsetMeters: 10,
                gpsOffsetStarboardMeters: 0,
                useBowOffsetForLineAssist: true,
                referenceBearingSource: .heading
            )
        )

        XCTAssertEqual(bowResult.status, .parallel)
        XCTAssertNil(bowResult.timeToLine)
        XCTAssertEqual(bowResult.bowGainToLineMeters ?? 0, 10, accuracy: 0.4)
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

    private func navigationFix(
        latitude: Double,
        longitude: Double,
        sogKnots: Double?,
        cogDegrees: Double?,
        headingDegrees: Double? = nil
    ) -> NavigationFix {
        NavigationFix(
            latitude: latitude,
            longitude: longitude,
            sogKnots: sogKnots,
            cogDegrees: cogDegrees,
            headingDegrees: headingDegrees,
            timestamp: Date(timeIntervalSinceReferenceDate: 0),
            source: .iPhoneGPS,
            horizontalAccuracyMeters: 3,
            hdop: nil,
            validFix: true
        )
    }

    private func knotsToMetersPerSecond(_ knots: Double) -> Double {
        knots * 1852 / 3600
    }
}
#endif
