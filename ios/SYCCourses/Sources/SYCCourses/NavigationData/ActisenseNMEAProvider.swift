import Foundation
import Network
import OSLog

@MainActor
final class ActisenseNMEAProvider: ObservableObject {
    @Published private(set) var status: NavigationSourceStatus = .disconnected
    @Published private(set) var latestFix: NavigationFix?
    @Published private(set) var lastError: String?
    @Published private(set) var messageCount = 0

    private var config: ActisenseInputConfig
    private var connection: NWConnection?
    private var buffer = Data()
    private var lastSOG: Double?
    private var lastCOG: Double?
    private var lastHeading: Double?
    private let logger = Logger(subsystem: "SYCCourses", category: "ActisenseNMEAInput")

    init(config: ActisenseInputConfig = ActisenseInputConfig()) {
        self.config = config
    }

    func configure(_ config: ActisenseInputConfig) {
        let requiresReconnect = self.config != config
        self.config = config
        if requiresReconnect, connection != nil {
            disconnect()
        }
        if !config.isConfigured {
            status = .disconnected
        }
    }

    func connect() async {
        disconnect()
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
                self?.handleConnectionState(state)
            }
        }
        nextConnection.start(queue: .global(qos: .utility))
        receive(on: nextConnection)
    }

    func disconnect() {
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
                    self.handle(data)
                }
                if let error {
                    self.setError(error.localizedDescription)
                    return
                }
                if isComplete {
                    self.status = .disconnected
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
            logger.info("Connected to Actisense NMEA input at \(self.config.host, privacy: .public):\(self.config.port)")
        case .preparing, .setup, .waiting:
            status = .connecting
        case let .failed(error):
            setError(error.localizedDescription)
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
        logger.error("Actisense input error: \(message, privacy: .public)")
    }
}

