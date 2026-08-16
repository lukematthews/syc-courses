import Foundation
import Network
import OSLog

@MainActor
final class ActisenseNMEAProvider: ObservableObject {
    @Published private(set) var status: NavigationSourceStatus = .disconnected
    @Published private(set) var latestFix: NavigationFix?
    @Published private(set) var lastError: String?
    @Published private(set) var messageCount = 0
    @Published private(set) var reconnectCount = 0
    @Published private(set) var lastDisconnectReason: String?

    private var config: ActisenseInputConfig
    private var connection: NWConnection?
    private var buffer = Data()
    private var lastSOG: Double?
    private var lastCOG: Double?
    private var lastHeading: Double?
    private var reconnectTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var shouldMaintainConnection = false
    private var reconnectAttempt = 0
    private var lastDataReceivedAt: Date?
    private let logger = Logger(subsystem: "SYCCourses", category: "NMEAGatewayInput")

    init(config: ActisenseInputConfig = ActisenseInputConfig()) {
        self.config = config
    }

    func configure(_ config: ActisenseInputConfig) {
        let requiresReconnect = self.config != config
        self.config = config
        if requiresReconnect, connection != nil || reconnectTask != nil {
            let restart = shouldMaintainConnection && config.isConfigured
            reconnectTask?.cancel()
            reconnectTask = nil
            stopConnection()
            shouldMaintainConnection = restart
            if restart {
                scheduleReconnect(immediately: true)
            }
        }
        if !config.isConfigured {
            status = .disconnected
        }
    }

    func connect() async {
        shouldMaintainConnection = true
        reconnectTask?.cancel()
        reconnectTask = nil
        startConnection()
    }

    private func startConnection() {
        stopConnection()
        guard config.isConfigured else {
            status = .disconnected
            return
        }
        status = .connecting
        lastError = nil

        let host = NWEndpoint.Host(config.host)
        guard let port = NWEndpoint.Port(rawValue: UInt16(config.port)) else {
            setError("Port must be between 1 and 65535.")
            return
        }

        let nextConnection = NWConnection(host: host, port: port, using: parameters(for: config.networkProtocol))
        connection = nextConnection
        nextConnection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self, self.connection === nextConnection else { return }
                self.handleConnectionState(state)
            }
        }
        nextConnection.start(queue: .global(qos: .utility))
        receive(on: nextConnection)
    }

    func disconnect() {
        shouldMaintainConnection = false
        reconnectTask?.cancel()
        reconnectTask = nil
        stopConnection()
    }

    private func stopConnection() {
        watchdogTask?.cancel()
        watchdogTask = nil
        connection?.cancel()
        connection = nil
        status = .disconnected
    }

    func ingest(sentence: String, now: Date = Date()) {
        guard let update = NMEASentenceParser.parse(sentence, now: now) else { return }
        apply(update, now: now)
        messageCount += 1
    }

    func isFresh(now: Date = Date()) -> Bool {
        guard let latestFix else { return false }
        return now.timeIntervalSince(latestFix.timestamp) <= config.staleAfterSeconds
    }

    func refreshFreshness(now: Date = Date()) {
        guard latestFix != nil else { return }
        if !isFresh(now: now), status == .receiving {
            status = .stale
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.lastDataReceivedAt = Date()
                    self.handle(data)
                }
                if let error {
                    self.handleDisconnect(error.localizedDescription)
                    return
                }
                if isComplete {
                    self.handleDisconnect("Gateway closed the connection")
                    return
                }
                if self.connection === connection {
                    self.receive(on: connection)
                }
            }
        }
    }

    private func handle(_ data: Data) {
        buffer.append(data)
        while let lineRange = buffer.firstRange(of: Data([0x0A])) {
            let lineData = buffer[..<lineRange.lowerBound]
            buffer.removeSubrange(...lineRange.lowerBound)
            if let line = String(data: lineData, encoding: .ascii) {
                ingest(sentence: line)
            }
        }
    }

    private func apply(_ update: ParsedNMEAUpdate, now: Date) {
        if let sog = update.sogKnots {
            lastSOG = sog
        }
        if let cog = update.cogDegrees {
            lastCOG = cog
        }
        if let heading = update.headingDegrees {
            lastHeading = heading
        }

        guard let fix = update.fix else {
            if latestFix != nil {
                latestFix = mergedFix(from: latestFix!, timestamp: now)
                status = latestFix?.validFix == true ? .receiving : .invalidFix
            }
            return
        }

        latestFix = mergedFix(from: fix, timestamp: fix.timestamp)
        status = latestFix?.validFix == true ? .receiving : .invalidFix
    }

    private func mergedFix(from fix: NavigationFix, timestamp: Date) -> NavigationFix {
        NavigationFix(
            latitude: fix.latitude,
            longitude: fix.longitude,
            sogKnots: fix.sogKnots ?? lastSOG,
            cogDegrees: fix.cogDegrees ?? lastCOG,
            headingDegrees: fix.headingDegrees ?? lastHeading,
            timestamp: timestamp,
            source: .actisense,
            horizontalAccuracyMeters: fix.horizontalAccuracyMeters,
            hdop: fix.hdop,
            validFix: fix.validFix
        )
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            status = .connected
            reconnectAttempt = 0
            reconnectTask?.cancel()
            reconnectTask = nil
            lastError = nil
            lastDataReceivedAt = Date()
            startWatchdog()
            logger.info("Connected to \(self.config.gateway.label, privacy: .public) NMEA input at \(self.config.host, privacy: .public):\(self.config.port)")
        case .preparing, .setup:
            status = .connecting
        case let .waiting(error):
            handleDisconnect("Connection waiting: \(error.localizedDescription)")
        case let .failed(error):
            handleDisconnect(error.localizedDescription)
        case .cancelled:
            status = .disconnected
        @unknown default:
            status = .connecting
        }
    }

    private func parameters(for networkProtocol: NavigationOutputProtocol) -> NWParameters {
        switch networkProtocol {
        case .tcp: .tcp
        case .udp: .udp
        }
    }

    private func setError(_ message: String) {
        lastError = message
        status = .error(message)
        logger.error("NMEA gateway input error: \(message, privacy: .public)")
    }

    private func handleDisconnect(_ reason: String) {
        watchdogTask?.cancel()
        watchdogTask = nil
        lastDisconnectReason = reason
        setError(reason)
        connection?.cancel()
        connection = nil
        scheduleReconnect()
    }

    private func scheduleReconnect(immediately: Bool = false) {
        guard shouldMaintainConnection, config.isConfigured, reconnectTask == nil else { return }
        let delay = immediately ? 0 : min(pow(2.0, Double(reconnectAttempt)), 30)
        reconnectAttempt += 1
        reconnectTask = Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard let self, !Task.isCancelled, self.shouldMaintainConnection else { return }
            self.reconnectTask = nil
            self.reconnectCount += 1
            self.startConnection()
        }
    }

    private func startWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled, self.shouldMaintainConnection else { return }
                let silenceLimit = max(self.config.staleAfterSeconds * 2, 10)
                if let lastDataReceivedAt = self.lastDataReceivedAt,
                   Date().timeIntervalSince(lastDataReceivedAt) > silenceLimit {
                    self.handleDisconnect("No NMEA data received for \(Int(silenceLimit)) seconds")
                    return
                }
            }
        }
    }
}
