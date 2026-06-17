import SwiftUI

struct NavigationOutputSettingsView: View {
    @EnvironmentObject private var navigationDataService: NavigationDataService
    @EnvironmentObject private var outputService: NavigationOutputService
    @State private var isShowingDiagnostics = false

    var body: some View {
        Form {
            Section {
                Text("Send course and waypoint information to your boat instruments using an Actisense W2K-2.")
                    .foregroundStyle(.secondary)
                Text("V1 sends NMEA 0183 waypoint sentences to the configured W2K-2 endpoint. Instrument display depends on W2K-2 configuration and downstream support.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Navigation Output") {
                Picker("Output", selection: $outputService.settings.target) {
                    ForEach(NavigationOutputTarget.allCases) { target in
                        Text(target.label).tag(target)
                    }
                }
                if outputService.settings.target == .actisenseW2K2 {
                    Picker("Protocol", selection: $outputService.settings.networkProtocol) {
                        ForEach(NavigationOutputProtocol.allCases) { networkProtocol in
                            Text(networkProtocol.label).tag(networkProtocol)
                        }
                    }
                    TextField("Host / IP address", text: $outputService.settings.host)
                        .autocorrectionDisabled()
                    TextField("Port", value: $outputService.settings.port, format: .number)
                    Toggle("Auto-connect", isOn: $outputService.settings.autoConnect)
                }
            }

            Section("Boat Data Input") {
                Toggle("Actisense enabled", isOn: $navigationDataService.actisenseConfig.isEnabled)
                TextField("Host / IP address", text: $navigationDataService.actisenseConfig.host)
                    .autocorrectionDisabled()
                TextField("Port", value: $navigationDataService.actisenseConfig.port, format: .number)
                Picker("Protocol", selection: $navigationDataService.actisenseConfig.networkProtocol) {
                    ForEach(NavigationOutputProtocol.allCases) { networkProtocol in
                        Text(networkProtocol.label).tag(networkProtocol)
                    }
                }
                LabeledContent("Status", value: navigationDataService.actisenseStatus.label)
                if let detail = navigationDataService.actisenseStatus.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                HStack {
                    Button("Test Connection") {
                        Task { await navigationDataService.connectActisense() }
                    }
                    .disabled(!navigationDataService.canConnectActisense)

                    Button("Disconnect") {
                        navigationDataService.disconnectActisense()
                    }
                    .disabled(navigationDataService.actisenseStatus == .disconnected)
                }
                Text("When Actisense provides a fresh valid position/SOG, Quick Bearing and Start Assist use boat data. If it goes stale, the app falls back to iPhone GPS.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Status") {
                LabeledContent("Status", value: outputService.status.label)
                if let detail = outputService.status.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                HStack {
                    Button("Connect") {
                        Task { await outputService.connect() }
                    }
                    .disabled(!outputService.canConnect || outputService.isConnected)

                    Button("Disconnect") {
                        outputService.disconnect()
                    }
                    .disabled(!outputService.isConnected)

                    Button("Test Output") {
                        Task { await outputService.testOutput() }
                    }
                    .disabled(!outputService.isConnected)
                }
            }

            Section {
                DisclosureGroup("Diagnostics / Advanced", isExpanded: $isShowingDiagnostics) {
                    DiagnosticsRows(diagnostics: outputService.diagnostics)
                }
            }
        }
        .navigationTitle("Navigation Output")
        .onAppear {
            if navigationDataService.actisenseConfig.isConfigured,
               navigationDataService.actisenseStatus == .disconnected {
                Task { await navigationDataService.connectActisense() }
            }
            if outputService.settings.autoConnect, outputService.canConnect, !outputService.isConnected {
                Task { await outputService.connect() }
            } else {
                outputService.refreshAdapterState()
            }
        }
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
    }
}
