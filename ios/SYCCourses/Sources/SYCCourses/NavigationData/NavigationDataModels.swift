import Foundation

enum NMEAWiFiGateway: String, CaseIterable, Codable, Identifiable {
    case actisenseW2K2
    case yachtDevicesYDWG02

    var id: String { rawValue }

    var label: String {
        switch self {
        case .actisenseW2K2: "Actisense W2K-2"
        case .yachtDevicesYDWG02: "Yacht Devices YDWG-02"
        }
    }

    var defaultHost: String { "192.168.4.1" }

    var defaultPort: Int {
        switch self {
        case .actisenseW2K2: 60001
        case .yachtDevicesYDWG02: 1456
        }
    }

    var defaultProtocol: NavigationOutputProtocol { .tcp }
}

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
    let statusMessage: String?
}

struct ActisenseInputConfig: Codable, Equatable {
    var gateway: NMEAWiFiGateway = .actisenseW2K2
    var isEnabled: Bool = false
    var host: String = "192.168.4.1"
    var port: Int = 60001
    var networkProtocol: NavigationOutputProtocol = .tcp
    var staleAfterSeconds: TimeInterval = 5

    var isConfigured: Bool {
        isEnabled && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...65535).contains(port)
    }

    init(
        gateway: NMEAWiFiGateway = .actisenseW2K2,
        isEnabled: Bool = false,
        host: String = "192.168.4.1",
        port: Int = 60001,
        networkProtocol: NavigationOutputProtocol = .tcp,
        staleAfterSeconds: TimeInterval = 5
    ) {
        self.gateway = gateway
        self.isEnabled = isEnabled
        self.host = host
        self.port = port
        self.networkProtocol = networkProtocol
        self.staleAfterSeconds = staleAfterSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case gateway, isEnabled, host, port, networkProtocol, staleAfterSeconds
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        gateway = try values.decodeIfPresent(NMEAWiFiGateway.self, forKey: .gateway) ?? .actisenseW2K2
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        host = try values.decodeIfPresent(String.self, forKey: .host) ?? gateway.defaultHost
        port = try values.decodeIfPresent(Int.self, forKey: .port) ?? gateway.defaultPort
        networkProtocol = try values.decodeIfPresent(NavigationOutputProtocol.self, forKey: .networkProtocol) ?? gateway.defaultProtocol
        staleAfterSeconds = try values.decodeIfPresent(TimeInterval.self, forKey: .staleAfterSeconds) ?? 5
    }
}
