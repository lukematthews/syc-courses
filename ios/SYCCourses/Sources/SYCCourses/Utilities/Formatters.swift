import Foundation

enum AppFormatters {
    static func bearing(_ value: Double) -> String {
        String(format: "%03.0f°T", NavigationMath.normalizeDegrees(value).rounded())
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
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
