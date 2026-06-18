import Foundation

enum LineCrossingCalculator {
    static func calculate(
        fix: NavigationFix?,
        lineStart: Mark,
        lineEnd: Mark,
        minimumSOGKnots: Double = 0.2,
        geometry: BoatGeometrySettings? = nil
    ) -> LineCrossingResult {
        NavigationMath.lineCrossing(
            fix: fix,
            lineStart: lineStart,
            lineEnd: lineEnd,
            minimumSOGKnots: minimumSOGKnots,
            geometry: geometry
        )
    }
}

enum NavigationMath {
    static let earthRadiusNm = 3440.065
    static let magneticVariationDegrees: Double? = nil

    static func normalizeDegrees(_ value: Double) -> Double {
        value.truncatingRemainder(dividingBy: 360).advanced(by: value < 0 ? 360 : 0)
            .truncatingRemainder(dividingBy: 360)
    }

    static func bearingTrue(fromLatitude fromLat: Double, fromLongitude fromLon: Double, toLatitude toLat: Double, toLongitude toLon: Double) -> Double {
        let fromLatRad = radians(fromLat)
        let toLatRad = radians(toLat)
        let deltaLonRad = radians(toLon - fromLon)
        let y = sin(deltaLonRad) * cos(toLatRad)
        let x = cos(fromLatRad) * sin(toLatRad) - sin(fromLatRad) * cos(toLatRad) * cos(deltaLonRad)
        return normalizeDegrees(degrees(atan2(y, x)))
    }

    static func distanceNm(fromLatitude fromLat: Double, fromLongitude fromLon: Double, toLatitude toLat: Double, toLongitude toLon: Double) -> Double {
        let deltaLat = radians(toLat - fromLat)
        let deltaLon = radians(toLon - fromLon)
        let fromLatRad = radians(fromLat)
        let toLatRad = radians(toLat)
        let a = pow(sin(deltaLat / 2), 2) + cos(fromLatRad) * cos(toLatRad) * pow(sin(deltaLon / 2), 2)
        return earthRadiusNm * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    static func magneticBearing(trueBearing: Double, variationDegrees: Double) -> Double {
        normalizeDegrees(trueBearing - variationDegrees)
    }

    static func timeToMark(distanceNm: Double, speedKnots: Double?) -> TimeInterval? {
        guard let speedKnots, speedKnots > 0.2 else { return nil }
        return (distanceNm / speedKnots) * 3600
    }

    static func timeToBurn(startTime: Date, now: Date, timeToMark: TimeInterval?) -> StartAssistSnapshot {
        let timeToStart = startTime.timeIntervalSince(now)
        return StartAssistSnapshot(
            startTime: startTime,
            timeToStart: timeToStart,
            timeToMark: timeToMark,
            timeToBurn: timeToMark.map { timeToStart - $0 }
        )
    }

    static func lineCrossing(
        fix: NavigationFix?,
        lineStart: Mark,
        lineEnd: Mark,
        minimumSOGKnots: Double = 0.2,
        geometry: BoatGeometrySettings? = nil
    ) -> LineCrossingResult {
        guard let fix, fix.isUsablePosition else {
            return LineCrossingResult(status: .insufficientData(.noGPS), distanceMeters: nil, timeToLine: nil)
        }

        let reference = calculateBoatReferencePoint(
            gpsPosition: LatLon(latitude: fix.latitude, longitude: fix.longitude),
            cogDegrees: fix.cogDegrees,
            headingDegrees: fix.headingDegrees,
            geometry: geometry ?? BoatGeometrySettings(useBowOffsetForLineAssist: false)
        )
        let referenceFix = NavigationFix(
            latitude: reference.position.latitude,
            longitude: reference.position.longitude,
            sogKnots: fix.sogKnots,
            cogDegrees: fix.cogDegrees,
            headingDegrees: fix.headingDegrees,
            timestamp: fix.timestamp,
            source: fix.source,
            horizontalAccuracyMeters: fix.horizontalAccuracyMeters,
            hdop: fix.hdop,
            validFix: fix.validFix
        )
        let diagnostics = lineDistanceDiagnostics(gpsFix: fix, referenceFix: referenceFix, lineStart: lineStart, lineEnd: lineEnd)

        guard let cogDegrees = fix.cogDegrees, cogDegrees.isFinite else {
            return LineCrossingResult(
                status: .insufficientData(.noCOG),
                distanceMeters: distanceMetersToSegment(from: referenceFix, lineStart: lineStart, lineEnd: lineEnd),
                timeToLine: nil,
                referencePoint: reference.referencePoint,
                isBowOffsetApplied: reference.isBowOffsetApplied,
                isDegraded: reference.isDegraded,
                degradedReason: reference.degradedReason,
                bowGainToLineMeters: diagnostics.bowGainToLineMeters,
                gpsDistanceToLineMeters: diagnostics.gpsDistanceToLineMeters,
                bowDistanceToLineMeters: diagnostics.bowDistanceToLineMeters
            )
        }
        guard let sogKnots = fix.sogKnots, sogKnots > minimumSOGKnots else {
            return LineCrossingResult(
                status: .insufficientData(.noSOG),
                distanceMeters: distanceMetersToSegment(from: referenceFix, lineStart: lineStart, lineEnd: lineEnd),
                timeToLine: nil,
                referencePoint: reference.referencePoint,
                isBowOffsetApplied: reference.isBowOffsetApplied,
                isDegraded: reference.isDegraded,
                degradedReason: reference.degradedReason,
                bowGainToLineMeters: diagnostics.bowGainToLineMeters,
                gpsDistanceToLineMeters: diagnostics.gpsDistanceToLineMeters,
                bowDistanceToLineMeters: diagnostics.bowDistanceToLineMeters
            )
        }

        let startPoint = projectedPoint(latitude: lineStart.latitude, longitude: lineStart.longitude, originLatitude: referenceFix.latitude, originLongitude: referenceFix.longitude)
        let endPoint = projectedPoint(latitude: lineEnd.latitude, longitude: lineEnd.longitude, originLatitude: referenceFix.latitude, originLongitude: referenceFix.longitude)
        let courseRadians = radians(cogDegrees)
        let travel = Point(x: sin(courseRadians), y: cos(courseRadians))
        let segment = Point(x: endPoint.x - startPoint.x, y: endPoint.y - startPoint.y)
        let denominator = cross(travel, segment)
        let distanceToSegment = distanceFromOriginToSegment(startPoint, endPoint)

        guard abs(denominator) > 0.000001 else {
            return lineCrossingResult(
                status: .parallel,
                distanceMeters: distanceToSegment,
                timeToLine: nil,
                reference: reference,
                diagnostics: diagnostics
            )
        }

        let t = cross(startPoint, segment) / denominator
        let u = cross(startPoint, travel) / denominator

        guard t >= 0 else {
            return lineCrossingResult(
                status: .movingAway,
                distanceMeters: distanceToSegment,
                timeToLine: nil,
                reference: reference,
                diagnostics: diagnostics
            )
        }
        guard (0...1).contains(u) else {
            return lineCrossingResult(
                status: .crossingOutsideSegment,
                distanceMeters: distanceToSegment,
                timeToLine: nil,
                reference: reference,
                diagnostics: diagnostics
            )
        }

        let speedMetersPerSecond = sogKnots * 1852 / 3600
        let timeToLine = t / speedMetersPerSecond
        let status: LineCrossingStatus = t <= 25 || timeToLine <= 10 ? .crossingAhead : .approachingLine
        return lineCrossingResult(
            status: status,
            distanceMeters: t,
            timeToLine: timeToLine,
            reference: reference,
            diagnostics: diagnostics
        )
    }

    static func calculateBoatReferencePoint(
        gpsPosition: LatLon,
        cogDegrees: Double?,
        headingDegrees: Double?,
        geometry: BoatGeometrySettings
    ) -> BoatReferencePointResult {
        guard geometry.useBowOffsetForLineAssist else {
            return BoatReferencePointResult(
                position: gpsPosition,
                referencePoint: .gps,
                isBowOffsetApplied: false,
                isDegraded: false,
                degradedReason: .disabled
            )
        }
        guard geometry.bowOffsetMeters > 0, geometry.bowOffsetMeters.isFinite else {
            return BoatReferencePointResult(
                position: gpsPosition,
                referencePoint: .gps,
                isBowOffsetApplied: false,
                isDegraded: true,
                degradedReason: .missingGeometry
            )
        }

        let referenceBearing: Double?
        switch geometry.referenceBearingSource {
        case .cog:
            referenceBearing = cogDegrees
        case .heading:
            referenceBearing = headingDegrees
        }

        guard let bearingDegrees = referenceBearing, bearingDegrees.isFinite else {
            return BoatReferencePointResult(
                position: gpsPosition,
                referencePoint: .gps,
                isBowOffsetApplied: false,
                isDegraded: true,
                degradedReason: geometry.referenceBearingSource == .heading ? .missingHeading : nil
            )
        }

        let referenceBearingDegrees = normalizeDegrees(bearingDegrees)
        var position = project(gpsPosition, distanceMeters: geometry.bowOffsetMeters, bearingDegrees: referenceBearingDegrees)
        let sidewaysOffset = geometry.gpsOffsetStarboardMeters
        if sidewaysOffset != 0, sidewaysOffset.isFinite {
            let bearing = sidewaysOffset > 0 ? referenceBearingDegrees - 90 : referenceBearingDegrees + 90
            position = project(position, distanceMeters: abs(sidewaysOffset), bearingDegrees: bearing)
        }
        return BoatReferencePointResult(
            position: position,
            referencePoint: .bow,
            isBowOffsetApplied: true,
            isDegraded: false,
            degradedReason: nil
        )
    }

    private static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func degrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }

    private struct Point {
        let x: Double
        let y: Double
    }

    private struct LineDistanceDiagnostics {
        let bowGainToLineMeters: Double?
        let gpsDistanceToLineMeters: Double?
        let bowDistanceToLineMeters: Double?
    }

    private static func lineCrossingResult(
        status: LineCrossingStatus,
        distanceMeters: Double?,
        timeToLine: TimeInterval?,
        reference: BoatReferencePointResult,
        diagnostics: LineDistanceDiagnostics
    ) -> LineCrossingResult {
        LineCrossingResult(
            status: status,
            distanceMeters: distanceMeters,
            timeToLine: timeToLine,
            referencePoint: reference.referencePoint,
            isBowOffsetApplied: reference.isBowOffsetApplied,
            isDegraded: reference.isDegraded,
            degradedReason: reference.degradedReason,
            bowGainToLineMeters: diagnostics.bowGainToLineMeters,
            gpsDistanceToLineMeters: diagnostics.gpsDistanceToLineMeters,
            bowDistanceToLineMeters: diagnostics.bowDistanceToLineMeters
        )
    }

    private static func lineDistanceDiagnostics(
        gpsFix: NavigationFix,
        referenceFix: NavigationFix,
        lineStart: Mark,
        lineEnd: Mark
    ) -> LineDistanceDiagnostics {
        let gpsDistance = distanceMetersToSegment(from: gpsFix, lineStart: lineStart, lineEnd: lineEnd)
        let bowDistance = distanceMetersToSegment(from: referenceFix, lineStart: lineStart, lineEnd: lineEnd)
        return LineDistanceDiagnostics(
            bowGainToLineMeters: gpsDistance - bowDistance,
            gpsDistanceToLineMeters: gpsDistance,
            bowDistanceToLineMeters: bowDistance
        )
    }

    private static func project(_ position: LatLon, distanceMeters: Double, bearingDegrees: Double) -> LatLon {
        let angularDistance = distanceMeters / (earthRadiusNm * 1852)
        let bearing = radians(normalizeDegrees(bearingDegrees))
        let latitude = radians(position.latitude)
        let longitude = radians(position.longitude)
        let projectedLatitude = asin(
            sin(latitude) * cos(angularDistance)
                + cos(latitude) * sin(angularDistance) * cos(bearing)
        )
        let projectedLongitude = longitude + atan2(
            sin(bearing) * sin(angularDistance) * cos(latitude),
            cos(angularDistance) - sin(latitude) * sin(projectedLatitude)
        )
        return LatLon(latitude: degrees(projectedLatitude), longitude: degrees(projectedLongitude))
    }

    private static func projectedPoint(latitude: Double, longitude: Double, originLatitude: Double, originLongitude: Double) -> Point {
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(radians(originLatitude))
        return Point(
            x: (longitude - originLongitude) * metersPerDegreeLongitude,
            y: (latitude - originLatitude) * metersPerDegreeLatitude
        )
    }

    private static func cross(_ lhs: Point, _ rhs: Point) -> Double {
        lhs.x * rhs.y - lhs.y * rhs.x
    }

    private static func distanceMetersToSegment(from fix: NavigationFix, lineStart: Mark, lineEnd: Mark) -> Double {
        let startPoint = projectedPoint(latitude: lineStart.latitude, longitude: lineStart.longitude, originLatitude: fix.latitude, originLongitude: fix.longitude)
        let endPoint = projectedPoint(latitude: lineEnd.latitude, longitude: lineEnd.longitude, originLatitude: fix.latitude, originLongitude: fix.longitude)
        return distanceFromOriginToSegment(startPoint, endPoint)
    }

    private static func distanceFromOriginToSegment(_ startPoint: Point, _ endPoint: Point) -> Double {
        let segment = Point(x: endPoint.x - startPoint.x, y: endPoint.y - startPoint.y)
        let lengthSquared = segment.x * segment.x + segment.y * segment.y
        guard lengthSquared > 0 else {
            return hypot(startPoint.x, startPoint.y)
        }
        let projection = min(1, max(0, -(startPoint.x * segment.x + startPoint.y * segment.y) / lengthSquared))
        let closest = Point(x: startPoint.x + projection * segment.x, y: startPoint.y + projection * segment.y)
        return hypot(closest.x, closest.y)
    }
}
