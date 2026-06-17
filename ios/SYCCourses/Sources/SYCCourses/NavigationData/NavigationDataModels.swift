import Foundation

enum NavigationSource: String, Codable, Equatable {
    case iPhoneGPS
    case actisense

    var label: String {
        switch self {
        case .iPhoneGPS: "iPhone GPS"
        case .actisense: "NMEA2000"
        }
    }
}

enum NavigationSourceStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case receiving
    case stale
    case error(String)
    case invalidFix

    var label: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .receiving: "Receiving"
        case .stale: "Stale"
        case .error: "Error"
        case .invalidFix: "Invalid fix"
        }
    }

    var detail: String? {
        if case let .error(message) = self {
            return message
        }
        return nil
    }
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
    let statusMessage: String
}

struct ActisenseInputConfig: Codable, Equatable {
    var isEnabled: Bool = false
    var host: String = "192.168.4.1"
    var port: Int = 60001
    var networkProtocol: NavigationOutputProtocol = .tcp
    var staleAfterSeconds: TimeInterval = 5

    var isConfigured: Bool {
        isEnabled && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...65535).contains(port)
    }
}
