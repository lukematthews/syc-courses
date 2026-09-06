import Foundation
import OSLog

extension Notification.Name {
    static let quickBearingOutputDidEnd = Notification.Name("quickBearingOutputDidEnd")
}

@MainActor
protocol NavigationOutputAdapter: AnyObject {
    var status: NavigationOutputStatus { get }
    var diagnostics: NavigationOutputDiagnostics { get }
    var stateDidChange: ((NavigationOutputStatus, NavigationOutputDiagnostics) -> Void)? { get set }

    func configure(_ settings: NavigationOutputSettings)
    func connect() async
    func disconnect()
    func send(_ messages: [NavigationOutputMessage]) async throws
}

@MainActor
final class NavigationOutputService: ObservableObject {
    @Published var settings: NavigationOutputSettings {
        didSet {
            persistSettings()
            rebuildAdapter()
        }
    }
    @Published private(set) var status: NavigationOutputStatus = .notConfigured
    @Published private(set) var diagnostics = NavigationOutputDiagnostics()
    @Published private(set) var isSending = false
    @Published private(set) var lastError: String?
    @Published private(set) var hasInstrumentAccess: Bool
    @Published private(set) var isQuickBearingOutputActive = false
    private(set) var isManuallyDisconnected = false

    private let defaults: UserDefaults
    private var adapterFactory: @MainActor (NavigationOutputSettings) -> NavigationOutputAdapter
    private var adapter: NavigationOutputAdapter?
    private let logger = Logger(subsystem: "SYCCourses", category: "NavigationOutput")
    private var reconnectTask: Task<Void, Never>?
    private var shouldMaintainConnection = false
    private var reconnectAttempt = 0
    private var reconnectCount = 0
    private var lastDisconnectReason: String?
    private var isConnectInProgress = false

    init(
        defaults: UserDefaults = .standard,
        hasInstrumentAccess: Bool = true,
        adapterFactory: @MainActor @escaping (NavigationOutputSettings) -> NavigationOutputAdapter = { NMEAWiFiGatewayAdapter(settings: $0) }
    ) {
        self.defaults = defaults
        self.hasInstrumentAccess = hasInstrumentAccess
        self.adapterFactory = adapterFactory
        settings = defaults.navigationOutputSettings
        rebuildAdapter()
    }

    var canConnect: Bool {
        hasInstrumentAccess && settings.target != .disabled && settings.isConfigured
    }

    var isConnected: Bool {
        status == .connected
    }

    func connect() async {
        isManuallyDisconnected = false
        guard hasInstrumentAccess else {
            logger.error("Navigation output connection blocked: instrument access is unavailable")
            updateStatus(.notConfigured)
            return
        }
        guard settings.target != .disabled else {
            logger.debug("Navigation output connection blocked: output is disabled")
            updateStatus(.notConfigured)
            return
        }
        guard settings.isConfigured else {
            logger.error("Navigation output connection blocked: gateway settings are incomplete")
            updateStatus(.notConfigured)
            return
        }
        shouldMaintainConnection = true
        reconnectTask?.cancel()
        reconnectTask = nil
        await performConnect()
    }

    func disconnect() {
        isManuallyDisconnected = true
        shouldMaintainConnection = false
        reconnectTask?.cancel()
        reconnectTask = nil
        adapter?.disconnect()
        syncAdapterState()
    }

    func beginQuickBearingOutput() {
        guard settings.target != .disabled, settings.isConfigured else { return }
        isQuickBearingOutputActive = true
    }

    func endQuickBearingOutput() {
        guard isQuickBearingOutputActive else { return }
        isQuickBearingOutputActive = false
        NotificationCenter.default.post(name: .quickBearingOutputDidEnd, object: nil)
    }

    func setInstrumentAccess(_ hasAccess: Bool) {
        guard hasAccess != hasInstrumentAccess else { return }
        hasInstrumentAccess = hasAccess
        if hasAccess {
            rebuildAdapter()
        } else {
            shouldMaintainConnection = false
            reconnectTask?.cancel()
            adapter?.disconnect()
            adapter = nil
            diagnostics = NavigationOutputDiagnostics()
            lastError = nil
            updateStatus(.notConfigured)
        }
    }

    func sendActiveWaypoint(_ waypoint: NavigationWaypointState?) async {
        do {
            guard let waypoint else {
                logger.error("Navigation output send blocked: no active waypoint was supplied")
                throw NavigationOutputError.noActiveWaypoint
            }
            try await send(
                messages: NMEA0183Encoder.messages(for: waypoint),
                description: "waypoint \(waypoint.waypointName)"
            )
        } catch {
            let message = error.localizedDescription
            lastError = message
            diagnostics.lastError = message
            updateStatus(status == .connected ? .connected : .error(message))
            logger.error("Navigation output failed: \(message, privacy: .public)")
        }
    }

    func clearActiveWaypoint() async {
        do {
            try await send(
                messages: NMEA0183Encoder.clearedWaypointMessages(),
                description: "cleared active waypoint"
            )
        } catch {
            let message = error.localizedDescription
            lastError = message
            diagnostics.lastError = message
            updateStatus(status == .connected ? .connected : .error(message))
            logger.error("Navigation output clear failed: \(message, privacy: .public)")
        }
    }

    @discardableResult
    func testOutput() async -> [String]? {
        let waypoint = NavigationWaypointState(
            courseNumber: 0,
            originName: "SYC",
            waypointName: "SYC 4",
            waypointID: "SYC4",
            latitude: -37.946833,
            longitude: 144.990000,
            bearingTrue: 180,
            magneticVariationDegrees: NavigationMath.magneticVariationDegrees,
            distanceNm: 0.10,
            speedOverGroundKnots: nil,
            timestamp: Date()
        )
        let messages = try? NMEA0183Encoder.messages(for: waypoint)
        await sendActiveWaypoint(waypoint)
        guard lastError == nil else { return nil }
        return messages?.map { $0.sentence.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func refreshAdapterState() {
        syncAdapterState()
    }

    private func send(messages: [NavigationOutputMessage], description: String) async throws {
        guard hasInstrumentAccess else {
            logger.error("Navigation output send blocked: instrument access is unavailable")
            throw NavigationOutputError.purchaseRequired
        }
        guard settings.target != .disabled else {
            logger.debug("Navigation output send blocked: output is disabled")
            throw NavigationOutputError.disabled
        }
        guard settings.isConfigured else {
            logger.error("Navigation output send blocked: gateway settings are incomplete")
            throw NavigationOutputError.notConfigured
        }
        ensureAdapter()
        if adapter?.status != .connected, settings.autoConnect, !isManuallyDisconnected {
            await performConnect()
        }
        guard adapter?.status == .connected else {
            syncAdapterState()
            logger.error("Navigation output send blocked: adapter status is \(self.status.label, privacy: .public)")
            throw NavigationOutputError.notConnected
        }

        isSending = true
        defer { isSending = false }
        do {
            try await adapter?.send(messages)
        } catch {
            syncAdapterState()
            guard settings.autoConnect else { throw error }
            logger.info("Navigation output send failed; reconnecting once before retry")
            await performConnect(isReconnect: true)
            guard adapter?.status == .connected else { throw error }
            try await adapter?.send(messages)
        }
        syncAdapterState()
        lastError = nil
        logger.info("Sent navigation output: \(description, privacy: .public)")
    }

    private func ensureAdapter() {
        if adapter == nil {
            rebuildAdapter()
        }
    }

    private func rebuildAdapter() {
        reconnectTask?.cancel()
        reconnectTask = nil
        adapter?.disconnect()
        guard hasInstrumentAccess else {
            adapter = nil
            updateStatus(.notConfigured)
            diagnostics = NavigationOutputDiagnostics()
            return
        }
        guard settings.target != .disabled else {
            adapter = nil
            updateStatus(.notConfigured)
            diagnostics = NavigationOutputDiagnostics()
            return
        }
        let next = adapterFactory(settings)
        next.stateDidChange = { [weak self, weak next] status, diagnostics in
            guard let self, self.adapter === next else { return }
            self.handleAdapterState(status, diagnostics: diagnostics)
        }
        next.configure(settings)
        adapter = next
        syncAdapterState()
        if shouldMaintainConnection, settings.autoConnect {
            scheduleReconnectIfNeeded()
        }
    }

    private func syncAdapterState() {
        guard let adapter else {
            updateStatus(.notConfigured)
            return
        }
        updateStatus(adapter.status)
        diagnostics = adapter.diagnostics
        diagnostics.reconnectCount = reconnectCount
        diagnostics.lastDisconnectReason = lastDisconnectReason
        if let error = diagnostics.lastError {
            lastError = error
        }
    }

    private func updateStatus(_ next: NavigationOutputStatus) {
        status = next
    }

    private func persistSettings() {
        defaults.navigationOutputSettings = settings
    }

    private func performConnect(isReconnect: Bool = false) async {
        guard canConnect else { return }
        guard !isConnectInProgress else {
            logger.debug("Navigation output connection already in progress")
            return
        }
        isConnectInProgress = true
        defer { isConnectInProgress = false }
        ensureAdapter()
        if isReconnect {
            reconnectCount += 1
            diagnostics.lastReconnectAttempt = Date()
        }
        updateStatus(.searching)
        await adapter?.connect()
        syncAdapterState()
    }

    private func handleAdapterState(_ next: NavigationOutputStatus, diagnostics adapterDiagnostics: NavigationOutputDiagnostics) {
        status = next
        diagnostics = adapterDiagnostics
        diagnostics.reconnectCount = reconnectCount
        diagnostics.lastDisconnectReason = lastDisconnectReason
        if case .connected = next {
            reconnectAttempt = 0
            reconnectTask?.cancel()
            reconnectTask = nil
            lastError = nil
            return
        }
        if case let .error(message) = next {
            lastError = message
            lastDisconnectReason = message
            diagnostics.lastDisconnectReason = message
        } else if case .disconnected = next {
            lastDisconnectReason = adapterDiagnostics.lastDisconnectReason ?? "Connection closed"
            diagnostics.lastDisconnectReason = lastDisconnectReason
        }
        if next == .disconnected || next.detail != nil {
            scheduleReconnectIfNeeded()
        }
    }

    private func scheduleReconnectIfNeeded() {
        guard shouldMaintainConnection, settings.autoConnect, reconnectTask == nil else { return }
        let delay = min(pow(2.0, Double(reconnectAttempt)), 30)
        reconnectAttempt += 1
        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, self.shouldMaintainConnection else { return }
            self.reconnectTask = nil
            await self.performConnect(isReconnect: true)
            if self.status != .connected {
                self.scheduleReconnectIfNeeded()
            }
        }
    }
}

private extension UserDefaults {
    var navigationOutputSettings: NavigationOutputSettings {
        get {
            guard let data = data(forKey: "navigationOutputSettings"),
                  let settings = try? JSONDecoder().decode(NavigationOutputSettings.self, from: data)
            else {
                return NavigationOutputSettings()
            }
            return settings
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                set(data, forKey: "navigationOutputSettings")
            }
        }
    }
}
