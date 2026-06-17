import Foundation

enum LineCrossingCalculator {
    static func calculate(
        fix: NavigationFix?,
        lineStart: Mark,
        lineEnd: Mark,
        minimumSOGKnots: Double = 0.2
    ) -> LineCrossingResult {
        NavigationMath.lineCrossing(
            fix: fix,
            lineStart: lineStart,
            lineEnd: lineEnd,
            minimumSOGKnots: minimumSOGKnots
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
        minimumSOGKnots: Double = 0.2
    ) -> LineCrossingResult {
        guard let fix, fix.isUsablePosition else {
            return LineCrossingResult(status: .insufficientData(.noGPS), distanceMeters: nil, timeToLine: nil)
        }
        guard let cogDegrees = fix.cogDegrees, cogDegrees.isFinite else {
            return LineCrossingResult(
                status: .insufficientData(.noCOG),
                distanceMeters: distanceMetersToSegment(from: fix, lineStart: lineStart, lineEnd: lineEnd),
                timeToLine: nil
            )
        }
        guard let sogKnots = fix.sogKnots, sogKnots > minimumSOGKnots else {
            return LineCrossingResult(
                status: .insufficientData(.noSOG),
                distanceMeters: distanceMetersToSegment(from: fix, lineStart: lineStart, lineEnd: lineEnd),
                timeToLine: nil
            )
        }

        let startPoint = projectedPoint(latitude: lineStart.latitude, longitude: lineStart.longitude, originLatitude: fix.latitude, originLongitude: fix.longitude)
        let endPoint = projectedPoint(latitude: lineEnd.latitude, longitude: lineEnd.longitude, originLatitude: fix.latitude, originLongitude: fix.longitude)
        let courseRadians = radians(cogDegrees)
        let travel = Point(x: sin(courseRadians), y: cos(courseRadians))
        let segment = Point(x: endPoint.x - startPoint.x, y: endPoint.y - startPoint.y)
        let denominator = cross(travel, segment)
        let distanceToSegment = distanceFromOriginToSegment(startPoint, endPoint)

        guard abs(denominator) > 0.000001 else {
            return LineCrossingResult(status: .parallel, distanceMeters: distanceToSegment, timeToLine: nil)
        }

        let t = cross(startPoint, segment) / denominator
        let u = cross(startPoint, travel) / denominator

        guard t >= 0 else {
            return LineCrossingResult(status: .movingAway, distanceMeters: distanceToSegment, timeToLine: nil)
        }
        guard (0...1).contains(u) else {
            return LineCrossingResult(status: .crossingOutsideSegment, distanceMeters: distanceToSegment, timeToLine: nil)
        }

        let speedMetersPerSecond = sogKnots * 1852 / 3600
        let timeToLine = t / speedMetersPerSecond
        let status: LineCrossingStatus = t <= 25 || timeToLine <= 10 ? .crossingAhead : .approachingLine
        return LineCrossingResult(status: status, distanceMeters: t, timeToLine: timeToLine)
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
