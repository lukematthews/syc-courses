import Foundation

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

    private static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func degrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}
