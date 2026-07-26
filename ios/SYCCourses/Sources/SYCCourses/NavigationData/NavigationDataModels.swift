import Foundation

enum NavigationSource: String, Codable, Equatable {
    case iPhoneGPS

    var label: String { "iPhone GPS" }
}

struct NavigationFix: Equatable {
    let latitude: Double
    let longitude: Double
    let sogKnots: Double?
    let cogDegrees: Double?
    let headingDegrees: Double?
    let timestamp: Date
    let source: NavigationSource
    let horizontalAccuracyMeters: Double?
    let hdop: Double?
    let validFix: Bool

    var isUsablePosition: Bool {
        validFix && latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180
    }
}

struct NavigationSourceSummary: Equatable {
    let activeSource: NavigationSource?
    let availableSources: [NavigationSource]
    let lastUpdate: Date?
    let statusMessage: String?
}
