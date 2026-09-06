import Foundation
import Network
import SwiftUI

private struct InstrumentFeedback: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct NavigationOutputSettingsView: View {
    @EnvironmentObject private var navigationDataService: NavigationDataService
    @EnvironmentObject private var outputService: NavigationOutputService
    @AppStorage("lineAssistBowOffsetMeters") private var bowOffsetMeters = 9.4
    @AppStorage("lineAssistGPSOffsetStarboardMeters") private var gpsOffsetStarboardMeters = 0.0
    @AppStorage("lineAssistUseBowOffset") private var useBowOffsetForLineAssist = true
    @AppStorage("lineAssistBowProjectionSource") private var bowProjectionSource = BoatReferenceBearingSource.cog.rawValue
    @AppStorage("navigationBearingDisplayReference") private var bearingReferenceRaw = NavigationBearingDisplayReference.trueNorth.rawValue
    @State private var isShowingDiagnostics = false
    @State private var isShowingBoatGeometryAdvanced = false
    @State private var discoveryStatus: GatewayDiscoveryStatus = .idle
    @State private var connectionTask: Task<Void, Never>?
    @State private var feedback: InstrumentFeedback?

    private var selectedGateway: NMEAWiFiGateway {
        navigationDataService.actisenseConfig.gateway
    }

    private var gateway: Binding<NMEAWiFiGateway> {
        Binding {
            selectedGateway
        } set: { value in
            guard value != selectedGateway else { return }
            var input = navigationDataService.actisenseConfig
            input.gateway = value
            input.host = value.defaultHost
            input.port = value.defaultPort
            input.networkProtocol = value.defaultProtocol
            navigationDataService.actisenseConfig = input

            var output = outputService.settings
            if output.target != .disabled {
                output.target = NavigationOutputTarget(gateway: value)
            }
            output.host = value.defaultHost
            output.port = value.defaultPort
            output.networkProtocol = value.defaultProtocol
            outputService.settings = output
            discoveryStatus = .idle
        }
    }

    private var actisenseHost: Binding<String> {
        Binding {
            sharedActisenseHost
        } set: { value in
            var input = navigationDataService.actisenseConfig
            input.host = value
            navigationDataService.actisenseConfig = input

            var output = outputService.settings
            output.host = value
            outputService.settings = output
        }
    }

    private var actisensePort: Binding<Int> {
        Binding {
            sharedActisensePort
        } set: { value in
            var input = navigationDataService.actisenseConfig
            input.port = value
            navigationDataService.actisenseConfig = input

            var output = outputService.settings
            output.port = value
            outputService.settings = output
        }
    }

    private var actisenseProtocol: Binding<NavigationOutputProtocol> {
        Binding {
            sharedActisenseProtocol
        } set: { value in
            var input = navigationDataService.actisenseConfig
            input.networkProtocol = value
            navigationDataService.actisenseConfig = input

            var output = outputService.settings
            output.networkProtocol = value
            outputService.settings = output
        }
    }

    private var actisenseInputEnabled: Binding<Bool> {
        Binding {
            navigationDataService.actisenseConfig.isEnabled
        } set: { value in
            var input = navigationDataService.actisenseConfig
            input.isEnabled = value
            navigationDataService.actisenseConfig = input
        }
    }

    private var actisenseOutputEnabled: Binding<Bool> {
        Binding {
            outputService.settings.target != .disabled
        } set: { value in
            var output = outputService.settings
            output.target = value ? NavigationOutputTarget(gateway: selectedGateway) : .disabled
            output.host = sharedActisenseHost
            output.port = sharedActisensePort
            output.networkProtocol = sharedActisenseProtocol
            outputService.settings = output
        }
    }

    private var sharedActisenseHost: String {
        if outputService.settings.target != .disabled,
           !navigationDataService.actisenseConfig.isEnabled,
           !outputService.settings.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return outputService.settings.host
        }
        if !navigationDataService.actisenseConfig.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return navigationDataService.actisenseConfig.host
        }
        return outputService.settings.host
    }

    private var sharedActisensePort: Int {
        if outputService.settings.target != .disabled, !navigationDataService.actisenseConfig.isEnabled {
            return outputService.settings.port
        }
        return navigationDataService.actisenseConfig.port
    }

    private var sharedActisenseProtocol: NavigationOutputProtocol {
        if outputService.settings.target != .disabled, !navigationDataService.actisenseConfig.isEnabled {
            return outputService.settings.networkProtocol
        }
        return navigationDataService.actisenseConfig.networkProtocol
    }

    private var canConnectActisense: Bool {
        navigationDataService.actisenseConfig.isConfigured || outputService.canConnect
    }

    private var isActisenseDisconnected: Bool {
        navigationDataService.actisenseStatus == .disconnected && !outputService.isConnected
    }

    var body: some View {
        Form {
            Section {
                Text("Configure an NMEA 2000 Wi-Fi gateway, then choose whether the app reads boat data from it, sends navigation output to it, or both.")
                    .foregroundStyle(.secondary)
                Text("Instrument display depends on the gateway configuration and downstream support.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(selectedGateway.label) {
                Picker("Gateway", selection: gateway) {
                    ForEach(NMEAWiFiGateway.allCases) { device in
                        Text(device.label).tag(device)
                    }
                }
                LabeledContent("IP address") {
                    TextField("192.168.4.1", text: actisenseHost)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Data server port") {
                    TextField("60001", value: actisensePort, formatter: Self.portFormatter)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Protocol", selection: actisenseProtocol) {
                    ForEach(NavigationOutputProtocol.allCases) { networkProtocol in
                        Text(networkProtocol.label).tag(networkProtocol)
                    }
                }
                Button {
                    Task { await findActisense() }
                } label: {
                    if discoveryStatus.isScanning {
                        Label("Finding Gateway", systemImage: "magnifyingglass")
                    } else {
                        Label("Find Gateway", systemImage: "magnifyingglass")
                    }
                }
                .disabled(discoveryStatus.isScanning)
                if let message = discoveryStatus.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(discoveryStatus.isError ? .red : .secondary)
                }
                Toggle("Use for boat data input", isOn: actisenseInputEnabled)
                Toggle("Send output to instruments", isOn: actisenseOutputEnabled)
                if outputService.settings.target != .disabled {
                    Toggle("Auto-connect output", isOn: $outputService.settings.autoConnect)
                }
                Text(gatewayHelpText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if selectedGateway == .yachtDevicesYDWG02, outputService.settings.target != .disabled {
                    Text("For output, configure the selected YDWG NMEA Server direction to allow data from the app (Both or Receive Only).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("Quick Bearing and Line Assist can use fresh valid position/SOG from the gateway. If it goes stale, the app falls back to iPhone GPS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Gateway Status") {
                LabeledContent("Input", value: navigationDataService.actisenseStatus.label)
                if let detail = navigationDataService.actisenseStatus.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                LabeledContent("Input reconnects", value: "\(navigationDataService.actisenseProvider.reconnectCount)")
                if let reason = navigationDataService.actisenseProvider.lastDisconnectReason {
                    LabeledContent("Last input disconnect", value: reason)
                }
                LabeledContent("Output", value: outputService.status.label)
                if let detail = outputService.status.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                HStack {
                    Button("Test Connection") {
                        connectionTask?.cancel()
                        connectionTask = Task { await connectActisense() }
                    }
                    .disabled(!canConnectActisense)

                    Button("Disconnect") {
                        disconnectActisense()
                    }
                    .disabled(isActisenseDisconnected)
                }

                Button("Test Output") {
                    Task {
                        if let sentences = await outputService.testOutput() {
                            feedback = InstrumentFeedback(
                                title: "Test Output Sent",
                                message: sentences.joined(separator: "\n\n")
                            )
                        } else {
                            feedback = InstrumentFeedback(
                                title: "Test Output Failed",
                                message: outputService.lastError ?? "No NMEA messages were sent."
                            )
                        }
                    }
                }
                .disabled(!outputService.isConnected)
            }

            Section("Bearing Display") {
                Picker("Bearing reference", selection: $bearingReferenceRaw) {
                    ForEach(NavigationBearingDisplayReference.allCases) { reference in
                        Text(reference.label).tag(reference.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text("Applies throughout the app, including the Lock Screen, Dynamic Island, and widgets.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Line Assist") {
                DisclosureGroup("Boat Geometry", isExpanded: $isShowingBoatGeometryAdvanced) {
                    Toggle("Use bow position for Line Assist", isOn: $useBowOffsetForLineAssist)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("GPS to bow distance")
                            Spacer()
                            TextField("9.4", value: $bowOffsetMeters, format: .number.precision(.fractionLength(1)))
                                .boatGeometryDecimalKeyboard()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 72)
                            Text("m")
                                .foregroundStyle(.secondary)
                        }
                        Text("GPS to bow distance is measured forward from the GPS/compass sensor to the bow.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("GPS sideways offset")
                            Spacer()
                            TextField("0", value: $gpsOffsetStarboardMeters, format: .number.precision(.fractionLength(1)))
                                .boatGeometrySignedDecimalKeyboard()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 72)
                            Text("m")
                                .foregroundStyle(.secondary)
                        }
                        Text("Positive values mean the sensor is to starboard of centreline; negative values mean port.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Bow projection", selection: $bowProjectionSource) {
                        Text("Course over ground").tag(BoatReferenceBearingSource.cog.rawValue)
                        Text("Heading").tag(BoatReferenceBearingSource.heading.rawValue)
                    }

                    Text("Course over ground is the default v1 behaviour. Heading projection is available once filtered heading data is reliable. Line Assist uses the bow position because the boat starts or finishes when the bow crosses the line.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                DisclosureGroup("Diagnostics / Advanced", isExpanded: $isShowingDiagnostics) {
                    DiagnosticsRows(diagnostics: outputService.diagnostics)
                }
            }
        }
        .navigationTitle("Instruments")
        .alert(item: $feedback) { feedback in
            Alert(
                title: Text(feedback.title),
                message: Text(feedback.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: bowOffsetMeters) { _, value in
            bowOffsetMeters = min(max(value, 0), 30)
        }
        .onChange(of: gpsOffsetStarboardMeters) { _, value in
            gpsOffsetStarboardMeters = min(max(value, -10), 10)
        }
        .onChange(of: bearingReferenceRaw) { _, _ in
            NotificationCenter.default.post(name: .navigationBearingDisplayReferenceDidChange, object: nil)
        }
        .onAppear {
            if outputService.settings.autoConnect,
               outputService.canConnect,
               !outputService.isConnected,
               !outputService.isManuallyDisconnected {
                Task { await outputService.connect() }
            } else {
                outputService.refreshAdapterState()
            }
        }
        .onDisappear {
            if !navigationDataService.hasNavigationInputOwners {
                navigationDataService.disconnectActisense(manually: false)
            }
        }
    }

    private func connectActisense() async {
        syncOutputDeviceConfig()
        let testsInput = navigationDataService.actisenseConfig.isConfigured
        let testsOutput = outputService.canConnect
        if testsInput {
            await navigationDataService.connectActisense()
        }
        if testsOutput {
            await outputService.connect()
        }

        for _ in 0..<60 where !connectionTestSucceeded(testsInput: testsInput, testsOutput: testsOutput) {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard !Task.isCancelled else { return }

        if connectionTestSucceeded(testsInput: testsInput, testsOutput: testsOutput) {
            var connected: [String] = []
            if testsInput { connected.append("input") }
            if testsOutput { connected.append("output") }
            feedback = InstrumentFeedback(
                title: "Connection Successful",
                message: "Connected to \(selectedGateway.label) for \(connected.joined(separator: " and "))."
            )
        } else {
            let details = navigationDataService.actisenseStatus.detail
                ?? outputService.status.detail
                ?? "The configured gateway did not reach the connected state."
            feedback = InstrumentFeedback(title: "Connection Failed", message: details)
        }
    }

    private func disconnectActisense() {
        connectionTask?.cancel()
        connectionTask = nil
        navigationDataService.disconnectActisense()
        outputService.disconnect()
        feedback = InstrumentFeedback(
            title: "Disconnected",
            message: "NMEA input and output have been disconnected. Automatic reconnection is paused until Test Connection is used."
        )
    }

    private func connectionTestSucceeded(testsInput: Bool, testsOutput: Bool) -> Bool {
        let inputConnected: Bool
        switch navigationDataService.actisenseStatus {
        case .connected, .receiving, .stale, .invalidFix:
            inputConnected = true
        case .disconnected, .connecting, .error:
            inputConnected = false
        }
        return (!testsInput || inputConnected) && (!testsOutput || outputService.isConnected)
    }

    private func syncOutputDeviceConfig() {
        var output = outputService.settings
        if output.target != .disabled {
            output.target = NavigationOutputTarget(gateway: selectedGateway)
        }
        output.host = sharedActisenseHost
        output.port = sharedActisensePort
        output.networkProtocol = sharedActisenseProtocol
        outputService.settings = output
    }

    private static let portFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        formatter.allowsFloats = false
        return formatter
    }()

    private var gatewayHelpText: String {
        switch selectedGateway {
        case .actisenseW2K2:
            "Use the TCP/UDP port configured on the W2K-2 for NMEA 0183 streaming. Common W2K setups use port 60001."
        case .yachtDevicesYDWG02:
            "The YDWG-02 factory NMEA Server #1 profile uses TCP port 1456 and NMEA 0183."
        }
    }

    private func findActisense() async {
        let configured = GatewayDiscoveryResult(
            host: sharedActisenseHost.trimmingCharacters(in: .whitespacesAndNewlines),
            port: sharedActisensePort
        )
        if navigationDataService.actisenseStatus == .connected
            || navigationDataService.actisenseStatus == .receiving
            || outputService.isConnected {
            discoveryStatus = .found(configured)
            return
        }

        discoveryStatus = .testingConfigured(configured)
        if await GatewayDiscovery.canConnect(
            to: configured.host,
            port: configured.port,
            networkProtocol: sharedActisenseProtocol,
            timeout: .seconds(6)
        ) {
            discoveryStatus = .found(configured)
            return
        }

        discoveryStatus = .scanningFallbacks
        let candidates = GatewayDiscovery.candidates(
            gateway: selectedGateway,
            currentHost: sharedActisenseHost,
            currentPort: sharedActisensePort
        ).filter { $0 != configured }
        if let result = await GatewayDiscovery.find(
            candidates: candidates,
            networkProtocol: sharedActisenseProtocol
        ) {
            actisenseHost.wrappedValue = result.host
            actisensePort.wrappedValue = result.port
            discoveryStatus = .found(result)
        } else {
            discoveryStatus = .notFound
        }
    }
}

private enum GatewayDiscoveryStatus: Equatable {
    case idle
    case testingConfigured(GatewayDiscoveryResult)
    case scanningFallbacks
    case found(GatewayDiscoveryResult)
    case notFound

    var isScanning: Bool {
        switch self {
        case .testingConfigured, .scanningFallbacks: true
        case .idle, .found, .notFound: false
        }
    }

    var isError: Bool {
        self == .notFound
    }

    var message: String? {
        switch self {
        case .idle:
            nil
        case let .testingConfigured(result):
            "Testing configured gateway at \(result.host):\(result.port)..."
        case .scanningFallbacks:
            "Configured gateway did not respond. Scanning fallback addresses and NMEA data ports..."
        case let .found(result):
            "Found a gateway at \(result.host):\(result.port)."
        case .notFound:
            "No NMEA data server found. Check Wi-Fi, IP address, and data server port."
        }
    }
}

private struct GatewayDiscoveryResult: Equatable {
    let host: String
    let port: Int
}

@MainActor
private enum GatewayDiscovery {
    static func candidates(
        gateway: NMEAWiFiGateway,
        currentHost: String,
        currentPort: Int
    ) -> [GatewayDiscoveryResult] {
        let hosts = unique([
            currentHost.trimmingCharacters(in: .whitespacesAndNewlines),
            "192.168.4.1",
            "192.168.1.1",
            "192.168.0.1",
            "10.0.0.1",
        ].filter { !$0.isEmpty })
        let devicePorts: [Int]
        switch gateway {
        case .actisenseW2K2:
            devicePorts = [60001, 60002, 60003]
        case .yachtDevicesYDWG02:
            devicePorts = [1456, 1457, 1458]
        }
        let ports = unique(([currentPort] + devicePorts).filter { (1...65_535).contains($0) })
        return hosts.flatMap { host in
            ports.map { port in GatewayDiscoveryResult(host: host, port: port) }
        }
    }

    static func find(
        candidates: [GatewayDiscoveryResult],
        networkProtocol: NavigationOutputProtocol
    ) async -> GatewayDiscoveryResult? {
        for candidate in candidates {
            if await canConnect(
                to: candidate.host,
                port: candidate.port,
                networkProtocol: networkProtocol,
                timeout: .milliseconds(750)
            ) {
                return candidate
            }
        }
        return nil
    }

    static func canConnect(
        to host: String,
        port: Int,
        networkProtocol: NavigationOutputProtocol,
        timeout: Duration
    ) async -> Bool {
        guard !host.isEmpty else { return false }
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return false }
        let parameters: NWParameters = networkProtocol == .tcp ? .tcp : .udp
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: parameters)
        return await withCheckedContinuation { continuation in
            var didResume = false

            func finish(_ success: Bool) {
                guard !didResume else { return }
                didResume = true
                connection.cancel()
                continuation.resume(returning: success)
            }

            connection.stateUpdateHandler = { nextState in
                Task { @MainActor in
                    switch nextState {
                    case .ready:
                        finish(true)
                    case .failed, .cancelled:
                        finish(false)
                    default:
                        break
                    }
                }
            }
            connection.start(queue: .global(qos: .utility))
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                finish(false)
            }
        }
    }

    private static func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        return values.filter { seen.insert($0).inserted }
    }
}

private struct DiagnosticsRows: View {
    let diagnostics: NavigationOutputDiagnostics

    var body: some View {
        LabeledContent("Device / host", value: diagnostics.deviceHost.isEmpty ? "Not configured" : diagnostics.deviceHost)
        LabeledContent("Connection", value: diagnostics.isConnected ? "Connected" : "Disconnected")
        LabeledContent("Last message sent", value: diagnostics.lastMessageSent ?? "None")
        LabeledContent("Message count", value: "\(diagnostics.messageCount)")
        LabeledContent("Last error", value: diagnostics.lastError ?? "None")
        LabeledContent("Last reconnect", value: diagnostics.lastReconnectAttempt?.formatted(date: .omitted, time: .standard) ?? "Never")
        LabeledContent("Reconnect count", value: "\(diagnostics.reconnectCount)")
        LabeledContent("Last disconnect", value: diagnostics.lastDisconnectReason ?? "None")
    }
}

private extension View {
    @ViewBuilder
    func boatGeometryDecimalKeyboard() -> some View {
        #if canImport(UIKit)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func boatGeometrySignedDecimalKeyboard() -> some View {
        #if canImport(UIKit)
        self.keyboardType(.numbersAndPunctuation)
        #else
        self
        #endif
    }
}
