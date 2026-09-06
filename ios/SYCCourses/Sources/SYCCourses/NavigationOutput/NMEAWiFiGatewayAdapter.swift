import Foundation
import Network
import OSLog

@MainActor
final class NMEAWiFiGatewayAdapter: NavigationOutputAdapter {
    private(set) var status: NavigationOutputStatus = .disconnected
    private(set) var diagnostics = NavigationOutputDiagnostics()
    var stateDidChange: ((NavigationOutputStatus, NavigationOutputDiagnostics) -> Void)?

    private var settings: NavigationOutputSettings
    private var connection: NWConnection?
    private let logger = Logger(subsystem: "SYCCourses", category: "NMEAWiFiGateway")

    init(settings: NavigationOutputSettings) {
        self.settings = settings
        diagnostics.deviceHost = "\(settings.host):\(settings.port) \(settings.networkProtocol.label)"
    }

    func configure(_ settings: NavigationOutputSettings) {
        self.settings = settings
        diagnostics.deviceHost = "\(settings.host):\(settings.port) \(settings.networkProtocol.label)"
        if !settings.isConfigured {
            status = .notConfigured
        }
    }

    func connect() async {
        // Replacing an in-flight attempt is internal connection management, not a
        // user-visible disconnect. Its callbacks must not change the new attempt.
        let previousConnection = connection
        connection = nil
        previousConnection?.stateUpdateHandler = nil
        previousConnection?.cancel()
        diagnostics.isConnected = false
        guard settings.isConfigured else {
            status = .notConfigured
            diagnostics.isConnected = false
            return
        }

        diagnostics.lastReconnectAttempt = Date()
        status = .searching

        let host = NWEndpoint.Host(settings.host)
        guard let port = NWEndpoint.Port(rawValue: UInt16(settings.port)) else {
            setError("Port must be between 1 and 65535.")
            return
        }

        let nextConnection = NWConnection(host: host, port: port, using: parameters(for: settings.networkProtocol))
        connection = nextConnection

        await withCheckedContinuation { continuation in
            var didResume = false

            nextConnection.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    guard self.connection === nextConnection else { return }
                    switch state {
                    case .ready:
                        self.status = .connected
                        self.diagnostics.isConnected = true
                        self.diagnostics.lastError = nil
                        self.logger.info("Connected to NMEA Wi-Fi gateway at \(self.settings.host, privacy: .public):\(self.settings.port)")
                        self.notifyStateChange()
                        if !didResume {
                            didResume = true
                            continuation.resume()
                        }
                    case let .failed(error):
                        self.setError(error.localizedDescription)
                        if !didResume {
                            didResume = true
                            continuation.resume()
                        }
                    case .cancelled:
                        self.status = .disconnected
                        self.diagnostics.isConnected = false
                        self.notifyStateChange()
                        if !didResume {
                            didResume = true
                            continuation.resume()
                        }
                    case .waiting:
                        if case let .waiting(error) = state {
                            self.setError("Connection waiting: \(error.localizedDescription)")
                        }
                    case .preparing, .setup:
                        self.status = .searching
                    @unknown default:
                        self.status = .searching
                    }
                }
            }

            nextConnection.start(queue: .global(qos: .utility))

            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run {
                    guard !didResume else { return }
                    didResume = true
                    if self.status != .connected {
                        self.setError("Connection timed out.")
                        nextConnection.cancel()
                    }
                    continuation.resume()
                }
            }
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        status = settings.isConfigured ? .disconnected : .notConfigured
        diagnostics.isConnected = false
        diagnostics.lastDisconnectReason = "Disconnected"
        notifyStateChange()
    }

    func send(_ messages: [NavigationOutputMessage]) async throws {
        guard status == .connected, let connection else {
            throw NavigationOutputError.notConnected
        }

        for message in messages {
            guard let data = message.sentence.data(using: .ascii) else {
                throw NavigationOutputError.encodingFailed("NMEA sentence could not be encoded as ASCII.")
            }
            try await send(data, on: connection)
            diagnostics.lastMessageSent = message.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            diagnostics.messageCount += 1
            logger.debug("Sent NMEA 0183 sentence: \(message.sentence, privacy: .public)")
        }
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                Task { @MainActor in
                    if let error {
                        self?.setError(error.localizedDescription)
                        continuation.resume(throwing: NavigationOutputError.transportFailed(error.localizedDescription))
                    } else {
                        continuation.resume()
                    }
                }
            })
        }
    }

    private func parameters(for networkProtocol: NavigationOutputProtocol) -> NWParameters {
        switch networkProtocol {
        case .tcp: .tcp
        case .udp: .udp
        }
    }

    private func setError(_ message: String) {
        status = .error(message)
        diagnostics.isConnected = false
        diagnostics.lastError = message
        diagnostics.lastDisconnectReason = message
        logger.error("NMEA Wi-Fi gateway adapter error: \(message, privacy: .public)")
        notifyStateChange()
    }

    private func notifyStateChange() {
        stateDidChange?(status, diagnostics)
    }
}
