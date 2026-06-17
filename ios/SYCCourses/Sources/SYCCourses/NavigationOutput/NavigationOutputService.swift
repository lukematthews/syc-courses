import Foundation
import OSLog

@MainActor
protocol NavigationOutputAdapter: AnyObject {
    var status: NavigationOutputStatus { get }
    var diagnostics: NavigationOutputDiagnostics { get }

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

    private let defaults: UserDefaults
    private var adapterFactory: @MainActor (NavigationOutputSettings) -> NavigationOutputAdapter
    private var adapter: NavigationOutputAdapter?
    private let logger = Logger(subsystem: "SYCCourses", category: "NavigationOutput")

    init(
        defaults: UserDefaults = .standard,
        adapterFactory: @MainActor @escaping (NavigationOutputSettings) -> NavigationOutputAdapter = { ActisenseW2K2Adapter(settings: $0) }
    ) {
        self.defaults = defaults
        self.adapterFactory = adapterFactory
        settings = defaults.navigationOutputSettings
        rebuildAdapter()
    }

    var canConnect: Bool {
        settings.target == .actisenseW2K2 && settings.isConfigured
    }

    var isConnected: Bool {
        status == .connected
    }

    func connect() async {
        guard settings.target != .disabled else {
            updateStatus(.notConfigured)
            return
        }
        guard settings.isConfigured else {
            updateStatus(.notConfigured)
            return
        }
        ensureAdapter()
        updateStatus(.searching)
        await adapter?.connect()
        syncAdapterState()
    }

    func disconnect() {
        adapter?.disconnect()
        syncAdapterState()
    }

    func sendActiveWaypoint(_ waypoint: NavigationWaypointState?) async {
        do {
            try await send(waypoint)
        } catch {
            let message = error.localizedDescription
            lastError = message
            diagnostics.lastError = message
            updateStatus(status == .connected ? .connected : .error(message))
            logger.error("Navigation output failed: \(message, privacy: .public)")
        }
    }

    func testOutput() async {
        let waypoint = NavigationWaypointState(
            courseNumber: 0,
            originName: "SYC",
            waypointName: "SYC 4",
            waypointID: "SYC4",
            latitude: -37.946833,
            longitude: 144.990000,
            bearingTrue: 180,
            distanceNm: 0.10,
            speedOverGroundKnots: nil,
            timestamp: Date()
        )
        await sendActiveWaypoint(waypoint)
    }

    func refreshAdapterState() {
        syncAdapterState()
    }

    private func send(_ waypoint: NavigationWaypointState?) async throws {
        guard settings.target != .disabled else { throw NavigationOutputError.disabled }
        guard settings.isConfigured else { throw NavigationOutputError.notConfigured }
        guard let waypoint else { throw NavigationOutputError.noActiveWaypoint }
        ensureAdapter()
        guard adapter?.status == .connected else { throw NavigationOutputError.notConnected }

        let messages = try NMEA0183Encoder.messages(for: waypoint)
        isSending = true
        defer { isSending = false }
        try await adapter?.send(messages)
        syncAdapterState()
        lastError = nil
        logger.info("Sent navigation output for course \(waypoint.courseNumber) waypoint \(waypoint.waypointName, privacy: .public)")
    }

    private func ensureAdapter() {
        if adapter == nil {
            rebuildAdapter()
        }
    }

    private func rebuildAdapter() {
        adapter?.disconnect()
        guard settings.target == .actisenseW2K2 else {
            adapter = nil
            updateStatus(.notConfigured)
            diagnostics = NavigationOutputDiagnostics()
            return
        }
        let next = adapterFactory(settings)
        next.configure(settings)
        adapter = next
        syncAdapterState()
    }

    private func syncAdapterState() {
        guard let adapter else {
            updateStatus(.notConfigured)
            return
        }
        updateStatus(adapter.status)
        diagnostics = adapter.diagnostics
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
