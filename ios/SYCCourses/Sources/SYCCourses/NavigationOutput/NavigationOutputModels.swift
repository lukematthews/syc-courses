import Foundation

enum NavigationOutputTarget: String, CaseIterable, Codable, Identifiable {
    case disabled
    case actisenseW2K2

    var id: String { rawValue }

    var label: String {
        switch self {
        case .disabled: "Disabled"
        case .actisenseW2K2: "Actisense W2K-2"
        }
    }
}

enum NavigationOutputProtocol: String, CaseIterable, Codable, Identifiable {
    case tcp
    case udp

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

enum NavigationOutputStatus: Equatable {
    case notConfigured
    case searching
    case connected
    case disconnected
    case error(String)

    var label: String {
        switch self {
        case .notConfigured: "Not configured"
        case .searching: "Searching"
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        case .error: "Error"
        }
    }

    var detail: String? {
        if case let .error(message) = self {
            return message
        }
        return nil
    }
}

struct NavigationOutputSettings: Codable, Equatable {
    var target: NavigationOutputTarget = .disabled
    var host: String = "192.168.4.1"
    var port: Int = 60001
    var networkProtocol: NavigationOutputProtocol = .tcp
    var autoConnect: Bool = false

    var isConfigured: Bool {
        target != .disabled && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...65535).contains(port)
    }
}

struct NavigationOutputDiagnostics: Equatable {
    var deviceHost: String = ""
    var isConnected: Bool = false
    var lastMessageSent: String?
    var messageCount: Int = 0
    var lastError: String?
    var lastReconnectAttempt: Date?
}

struct NavigationWaypointState: Equatable {
    let courseNumber: Int
    let originName: String
    let waypointName: String
    let waypointID: String
    let latitude: Double
    let longitude: Double
    let bearingTrue: Double
    let distanceNm: Double
    let speedOverGroundKnots: Double?
    let timestamp: Date
}

struct NavigationOutputMessage: Equatable {
    let sentence: String
}

enum NavigationOutputError: LocalizedError, Equatable {
    case disabled
    case notConfigured
    case notConnected
    case noActiveWaypoint
    case encodingFailed(String)
    case transportFailed(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            "Navigation output is disabled."
        case .notConfigured:
            "Navigation output is not configured."
        case .notConnected:
            "Navigation output is not connected."
        case .noActiveWaypoint:
            "No active waypoint is available."
        case let .encodingFailed(message):
            message
        case let .transportFailed(message):
            message
        }
    }
}

