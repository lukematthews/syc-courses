import Foundation

enum NavigationBearingDisplayReference: String, CaseIterable, Identifiable {
    case trueNorth
    case magnetic

    var id: String { rawValue }
    var label: String { self == .trueNorth ? "True" : "Magnetic" }
}

enum AppFormatters {
    static func bearing(_ value: Double) -> String {
        String(format: "%03.0f°T", NavigationMath.normalizeDegrees(value).rounded())
    }

    static func bearing(
        trueBearing: Double,
        reference: NavigationBearingDisplayReference,
        variationDegrees: Double? = NavigationMath.magneticVariationDegrees
    ) -> String {
        switch reference {
        case .trueNorth:
            return bearing(trueBearing)
        case .magnetic:
            guard let variationDegrees else { return bearing(trueBearing) }
            let magnetic = NavigationMath.magneticBearing(
                trueBearing: trueBearing,
                variationDegrees: variationDegrees
            )
            return String(format: "%03.0f°M", magnetic.rounded())
        }
    }

    static func distanceNm(_ value: Double) -> String {
        value < 1 ? String(format: "%.2f nm", value) : String(format: "%.1f nm", value)
    }

    static func speedKnots(_ value: Double?) -> String {
        guard let value else { return "-- kt" }
        return String(format: "%.1f kt", max(0, value))
    }

    static func duration(_ interval: TimeInterval?) -> String {
        guard let interval else { return "--:--" }
        let seconds = Int(abs(interval).rounded())
        let hours = seconds / 3600
        let minutes = (seconds / 60) % 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
