#if canImport(XCTest)
@testable import SYCCourses
import XCTest

@MainActor
final class NavigationOutputTests: XCTestCase {
    func testPurchaseRequiredBlocksConnectionAndOutput() async {
        let adapter = FakeNavigationOutputAdapter()
        let defaults = UserDefaults(suiteName: "NavigationOutputTests-\(UUID().uuidString)")!
        let service = NavigationOutputService(
            defaults: defaults,
            hasInstrumentAccess: false,
            adapterFactory: { _ in adapter }
        )
        service.settings = NavigationOutputSettings(
            target: .actisenseW2K2,
            host: "192.168.4.1",
            port: 60001,
            networkProtocol: .tcp,
            autoConnect: true
        )

        await service.connect()
        await service.sendActiveWaypoint(sampleWaypoint())

        XCTAssertFalse(service.canConnect)
        XCTAssertEqual(service.status, .error(NavigationOutputError.purchaseRequired.localizedDescription))
        XCTAssertEqual(service.lastError, NavigationOutputError.purchaseRequired.localizedDescription)
        XCTAssertTrue(adapter.sentMessages.isEmpty)
    }

    func testRevokingAccessDisconnectsOutput() async {
        let adapter = FakeNavigationOutputAdapter()
        let service = makeService(adapter: adapter, target: .actisenseW2K2)

        await service.connect()
        service.setInstrumentAccess(false)

        XCTAssertFalse(adapter.diagnostics.isConnected)
        XCTAssertFalse(service.canConnect)
        XCTAssertEqual(service.status, .notConfigured)
    }

    func testNoOutputWhenDisabled() async {
        let adapter = FakeNavigationOutputAdapter()
        let service = makeService(adapter: adapter)

        await service.sendActiveWaypoint(sampleWaypoint())

        XCTAssertEqual(service.lastError, NavigationOutputError.disabled.localizedDescription)
        XCTAssertTrue(adapter.sentMessages.isEmpty)
    }

    func testNoOutputWhenNoActiveWaypointExists() async {
        let adapter = FakeNavigationOutputAdapter()
        let service = makeService(adapter: adapter, target: .actisenseW2K2)

        await service.connect()
        await service.sendActiveWaypoint(nil)

        XCTAssertEqual(service.status, .connected)
        XCTAssertEqual(service.lastError, NavigationOutputError.noActiveWaypoint.localizedDescription)
        XCTAssertTrue(adapter.sentMessages.isEmpty)
    }

    func testServiceSendsActiveWaypointMessages() async {
        let adapter = FakeNavigationOutputAdapter()
        let service = makeService(adapter: adapter, target: .actisenseW2K2)

        await service.connect()
        await service.sendActiveWaypoint(sampleWaypoint())

        XCTAssertEqual(service.status, .connected)
        XCTAssertEqual(adapter.sentMessages.count, 2)
        XCTAssertTrue(adapter.sentMessages[0].sentence.hasPrefix("$GPBWC"))
        XCTAssertTrue(adapter.sentMessages[1].sentence.hasPrefix("$GPRMB"))
    }

    func testActiveCourseUsesProvenWaypointSendPath() async throws {
        let suiteName = "NavigationOutputTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let adapter = FakeNavigationOutputAdapter()
        let provider = ActisenseNMEAProvider()
        let navigationDataService = NavigationDataService(
            defaults: defaults,
            actisenseProvider: provider,
            hasInstrumentAccess: true
        )
        navigationDataService.actisenseConfig = ActisenseInputConfig(
            isEnabled: true,
            staleAfterSeconds: 5
        )
        provider.ingest(
            sentence: "$GPGGA,092751.000,3756.8100,S,14459.4000,E,1,08,0.9,0.0,M,0.0,M,,*00",
            now: Date()
        )

        let outputService = NavigationOutputService(
            defaults: defaults,
            hasInstrumentAccess: true,
            adapterFactory: { _ in adapter }
        )
        outputService.settings = NavigationOutputSettings(
            target: .actisenseW2K2,
            host: "192.168.4.1",
            port: 60001,
            networkProtocol: .tcp,
            autoConnect: false
        )
        await outputService.connect()

        let activeRaceStore = ActiveRaceStore(defaults: defaults)
        let locationService = LocationService()
        let coordinator = CourseNavigationSurfaceCoordinator()
        coordinator.configure(
            activeRaceStore: activeRaceStore,
            locationService: locationService,
            navigationDataService: navigationDataService,
            navigationOutputService: outputService
        )
        activeRaceStore.setActiveCourse(try XCTUnwrap(CourseDataLoader.fixedCourses().first))

        for _ in 0..<50 where adapter.sentMessages.count < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(adapter.sentMessages.count, 2)
        XCTAssertTrue(adapter.sentMessages[0].sentence.hasPrefix("$GPBWC"))
        XCTAssertTrue(adapter.sentMessages[1].sentence.hasPrefix("$GPRMB"))
    }

    func testServiceSupportsYDWGOutput() async {
        let adapter = FakeNavigationOutputAdapter()
        let service = makeService(adapter: adapter, target: .yachtDevicesYDWG02, port: 1456)

        await service.connect()
        await service.sendActiveWaypoint(sampleWaypoint())

        XCTAssertEqual(service.status, .connected)
        XCTAssertEqual(adapter.sentMessages.count, 2)
        XCTAssertTrue(service.canConnect)
    }

    func testAdapterStateTransitionsSurfaceThroughService() async {
        let adapter = FakeNavigationOutputAdapter()
        let service = makeService(adapter: adapter, target: .actisenseW2K2)

        XCTAssertEqual(service.status, .disconnected)

        await service.connect()
        XCTAssertEqual(service.status, .connected)

        service.disconnect()
        XCTAssertEqual(service.status, .disconnected)
    }

    func testUnexpectedAdapterFailureSurfacesWithoutPolling() async {
        let adapter = FakeNavigationOutputAdapter()
        let service = makeService(adapter: adapter, target: .actisenseW2K2)

        await service.connect()
        adapter.simulateFailure("Wi-Fi link lost")

        XCTAssertEqual(service.status, .error("Wi-Fi link lost"))
        XCTAssertEqual(service.diagnostics.lastDisconnectReason, "Wi-Fi link lost")
    }

    func testQuickBearingTemporarilyOwnsInstrumentOutput() {
        let adapter = FakeNavigationOutputAdapter()
        let service = makeService(adapter: adapter, target: .actisenseW2K2)

        service.beginQuickBearingOutput()
        XCTAssertTrue(service.isQuickBearingOutputActive)

        let ended = expectation(forNotification: .quickBearingOutputDidEnd, object: nil)
        service.endQuickBearingOutput()

        wait(for: [ended], timeout: 0.1)
        XCTAssertFalse(service.isQuickBearingOutputActive)
    }

    func testFailedSendReconnectsAndRetriesOnce() async {
        let adapter = FakeNavigationOutputAdapter()
        let service = makeService(adapter: adapter, target: .actisenseW2K2, autoConnect: true)

        await service.connect()
        adapter.failNextSend = true
        await service.sendActiveWaypoint(sampleWaypoint())

        XCTAssertEqual(service.status, .connected)
        XCTAssertEqual(adapter.connectCount, 2)
        XCTAssertEqual(adapter.sentMessages.count, 2)
        XCTAssertEqual(service.diagnostics.reconnectCount, 1)
    }

    func testMessageGenerationRejectsInvalidDistance() {
        let waypoint = NavigationWaypointState(
            courseNumber: 1,
            originName: "SYC",
            waypointName: "SYC 1",
            waypointID: "SYC 1",
            latitude: -37.963333,
            longitude: 144.9815,
            bearingTrue: 202,
            distanceNm: -.infinity,
            speedOverGroundKnots: nil,
            timestamp: Date(timeIntervalSinceReferenceDate: 0)
        )

        XCTAssertThrowsError(try NMEA0183Encoder.messages(for: waypoint)) { error in
            XCTAssertEqual(error as? NavigationOutputError, .encodingFailed("Waypoint distance is invalid."))
        }
    }

    func testNMEAChecksumGeneration() {
        XCTAssertEqual(NMEA0183Encoder.checksum("GPRMC,092751.000,A,5321.6802,N,00630.3372,W,0.06,31.66,280511,,,A"), "46")
    }

    func testBWCIncludesConsistentTrueAndMagneticBearings() throws {
        var waypoint = sampleWaypoint()
        waypoint.magneticVariationDegrees = 12

        let sentence = try XCTUnwrap(NMEA0183Encoder.messages(for: waypoint).first?.sentence)

        XCTAssertTrue(sentence.contains(",202.1,T,190.1,M,1.07,N,"))
    }

    private func makeService(
        adapter: FakeNavigationOutputAdapter,
        target: NavigationOutputTarget = .disabled,
        port: Int = 60001,
        autoConnect: Bool = false
    ) -> NavigationOutputService {
        let defaults = UserDefaults(suiteName: "NavigationOutputTests-\(UUID().uuidString)")!
        let service = NavigationOutputService(
            defaults: defaults,
            hasInstrumentAccess: true,
            adapterFactory: { _ in adapter }
        )
        service.settings = NavigationOutputSettings(
            target: target,
            host: "192.168.4.1",
            port: port,
            networkProtocol: .tcp,
            autoConnect: autoConnect
        )
        return service
    }

    private func sampleWaypoint() -> NavigationWaypointState {
        NavigationWaypointState(
            courseNumber: 1,
            originName: "SYC",
            waypointName: "SYC 1",
            waypointID: "SYC 1",
            latitude: -37.963333,
            longitude: 144.9815,
            bearingTrue: 202.1,
            distanceNm: 1.07,
            speedOverGroundKnots: 5.4,
            timestamp: Date(timeIntervalSinceReferenceDate: 0)
        )
    }
}

@MainActor
private final class FakeNavigationOutputAdapter: NavigationOutputAdapter {
    var status: NavigationOutputStatus = .disconnected
    var diagnostics = NavigationOutputDiagnostics()
    var stateDidChange: ((NavigationOutputStatus, NavigationOutputDiagnostics) -> Void)?
    var sentMessages: [NavigationOutputMessage] = []
    var connectCount = 0
    var failNextSend = false

    func configure(_ settings: NavigationOutputSettings) {
        diagnostics.deviceHost = "\(settings.host):\(settings.port) \(settings.networkProtocol.label)"
        status = settings.isConfigured ? .disconnected : .notConfigured
    }

    func connect() async {
        connectCount += 1
        status = .connected
        diagnostics.isConnected = true
        stateDidChange?(status, diagnostics)
    }

    func disconnect() {
        status = .disconnected
        diagnostics.isConnected = false
        stateDidChange?(status, diagnostics)
    }

    func send(_ messages: [NavigationOutputMessage]) async throws {
        guard status == .connected else {
            throw NavigationOutputError.notConnected
        }
        if failNextSend {
            failNextSend = false
            simulateFailure("Simulated transport failure")
            throw NavigationOutputError.transportFailed("Simulated transport failure")
        }
        sentMessages.append(contentsOf: messages)
        diagnostics.messageCount += messages.count
        diagnostics.lastMessageSent = messages.last?.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func simulateFailure(_ message: String) {
        status = .error(message)
        diagnostics.isConnected = false
        diagnostics.lastError = message
        diagnostics.lastDisconnectReason = message
        stateDidChange?(status, diagnostics)
    }
}
#endif
