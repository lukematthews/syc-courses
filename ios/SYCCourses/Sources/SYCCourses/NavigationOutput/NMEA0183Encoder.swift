import Foundation

enum NMEA0183Encoder {
    static func messages(for waypoint: NavigationWaypointState) throws -> [NavigationOutputMessage] {
        guard waypoint.distanceNm.isFinite, waypoint.distanceNm >= 0 else {
            throw NavigationOutputError.encodingFailed("Waypoint distance is invalid.")
        }
        guard waypoint.bearingTrue.isFinite else {
            throw NavigationOutputError.encodingFailed("Waypoint bearing is invalid.")
        }

        return [
            NavigationOutputMessage(sentence: sentence(fields: bwcFields(for: waypoint))),
            NavigationOutputMessage(sentence: sentence(fields: rmbFields(for: waypoint)))
        ]
    }

    static func sentence(fields: [String]) -> String {
        let body = fields.joined(separator: ",")
        return "$\(body)*\(checksum(body))\r\n"
    }

    static func checksum(_ body: String) -> String {
        let value = body.utf8.reduce(UInt8(0)) { $0 ^ $1 }
        return String(format: "%02X", value)
    }

    static func waypointID(from value: String) -> String {
        let allowed = value.uppercased().filter { character in
            character.isASCII && (character.isLetter || character.isNumber)
        }
        return String(allowed.prefix(8))
    }

    private static func bwcFields(for waypoint: NavigationWaypointState) -> [String] {
        let coordinate = coordinateFields(latitude: waypoint.latitude, longitude: waypoint.longitude)
        return [
            "GPBWC",
            utcTime(waypoint.timestamp),
            coordinate.latitudeValue,
            coordinate.latitudeHemisphere,
            coordinate.longitudeValue,
            coordinate.longitudeHemisphere,
            formatBearing(waypoint.bearingTrue),
            "T",
            "",
            "M",
            formatDistance(waypoint.distanceNm),
            "N",
            waypointID(from: waypoint.waypointID),
            "A"
        ]
    }

    private static func rmbFields(for waypoint: NavigationWaypointState) -> [String] {
        let coordinate = coordinateFields(latitude: waypoint.latitude, longitude: waypoint.longitude)
        return [
            "GPRMB",
            "A",
            "0.00",
            "L",
            waypointID(from: waypoint.originName),
            waypointID(from: waypoint.waypointID),
            coordinate.latitudeValue,
            coordinate.latitudeHemisphere,
            coordinate.longitudeValue,
            coordinate.longitudeHemisphere,
            formatDistance(waypoint.distanceNm),
            formatBearing(waypoint.bearingTrue),
            formatSpeed(waypoint.speedOverGroundKnots),
            "A",
            "A"
        ]
    }

    private static func coordinateFields(latitude: Double, longitude: Double) -> (
        latitudeValue: String,
        latitudeHemisphere: String,
        longitudeValue: String,
        longitudeHemisphere: String
    ) {
        (
            coordinateValue(abs(latitude), degreeDigits: 2),
            latitude >= 0 ? "N" : "S",
            coordinateValue(abs(longitude), degreeDigits: 3),
            longitude >= 0 ? "E" : "W"
        )
    }

    private static func coordinateValue(_ degrees: Double, degreeDigits: Int) -> String {
        let wholeDegrees = Int(degrees)
        let minutes = (degrees - Double(wholeDegrees)) * 60
        return String(format: "%0*d%07.4f", degreeDigits, wholeDegrees, minutes)
    }

    private static func utcTime(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date)
        return String(format: "%02d%02d%02d", components.hour ?? 0, components.minute ?? 0, components.second ?? 0)
    }

    private static func formatBearing(_ bearing: Double) -> String {
        String(format: "%.1f", NavigationMath.normalizeDegrees(bearing))
    }

    private static func formatDistance(_ distance: Double) -> String {
        String(format: "%.2f", max(0, distance))
    }

    private static func formatSpeed(_ speed: Double?) -> String {
        guard let speed, speed.isFinite, speed >= 0 else { return "0.0" }
        return String(format: "%.1f", speed)
    }
}

