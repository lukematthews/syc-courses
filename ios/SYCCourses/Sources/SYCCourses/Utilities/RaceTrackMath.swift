import CoreLocation
import Foundation

struct RaceTrackPoint: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct SavedRaceTrack: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let startedAt: Date
    var name: String?
    var endedAt: Date
    var points: [RaceTrackPoint]

    var duration: TimeInterval {
        RaceTrackMath.duration(for: points) ?? 0
    }

    var displayName: String {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return RaceTrackFormatters.defaultName(startedAt)
        }
        return name
    }
}

enum RaceTrackMath {
    static func duration(for points: [RaceTrackPoint]) -> TimeInterval? {
        guard let first = points.first, let last = points.last else { return nil }
        return max(0, last.timestamp.timeIntervalSince(first.timestamp))
    }

    static func coordinate(at offset: TimeInterval, in points: [RaceTrackPoint]) -> CLLocationCoordinate2D? {
        guard let first = points.first else { return nil }
        guard points.count > 1 else { return first.coordinate }

        let target = first.timestamp.addingTimeInterval(max(0, offset))
        if target <= first.timestamp { return first.coordinate }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            guard target <= current.timestamp else { continue }

            let segmentDuration = current.timestamp.timeIntervalSince(previous.timestamp)
            guard segmentDuration > 0 else { return current.coordinate }

            let progress = target.timeIntervalSince(previous.timestamp) / segmentDuration
            return CLLocationCoordinate2D(
                latitude: previous.latitude + ((current.latitude - previous.latitude) * progress),
                longitude: previous.longitude + ((current.longitude - previous.longitude) * progress)
            )
        }

        return points.last?.coordinate
    }
}

enum RaceTrackFormatters {
    static func defaultName(_ date: Date) -> String {
        "Race - \(start(date))"
    }

    static func start(_ date: Date) -> String {
        startFormatter.string(from: date)
    }

    private static let startFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
