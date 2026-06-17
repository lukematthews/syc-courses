#if canImport(XCTest)
@testable import SYCCourses
import XCTest

@MainActor
final class NavigationOutputTests: XCTestCase {
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

    func testAdapterStateTransitionsSurfaceThroughService() async {
        let adapter = FakeNavigationOutputAdapter()
        let service = makeService(adapter: adapter, target: .actisenseW2K2)

        XCTAssertEqual(service.status, .disconnected)

        await service.connect()
        XCTAssertEqual(service.status, .connected)

        service.disconnect()
        XCTAssertEqual(service.status, .disconnected)
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

    private func makeService(
        adapter: FakeNavigationOutputAdapter,
        target: NavigationOutputTarget = .disabled
    ) -> NavigationOutputService {
        let defaults = UserDefaults(suiteName: "NavigationOutputTests-\(UUID().uuidString)")!
        let service = NavigationOutputService(defaults: defaults) { _ in adapter }
        service.settings = NavigationOutputSettings(
            target: target,
            host: "192.168.4.1",
            port: 60001,
            networkProtocol: .tcp,
            autoConnect: false
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
    var sentMessages: [NavigationOutputMessage] = []

    func configure(_ settings: NavigationOutputSettings) {
        diagnostics.deviceHost = "\(settings.host):\(settings.port) \(settings.networkProtocol.label)"
        status = settings.isConfigured ? .disconnected : .notConfigured
    }

    func connect() async {
        status = .connected
        diagnostics.isConnected = true
    }

    func disconnect() {
        status = .disconnected
        diagnostics.isConnected = false
    }

    func send(_ messages: [NavigationOutputMessage]) async throws {
        guard status == .connected else {
            throw NavigationOutputError.notConnected
        }
        sentMessages.append(contentsOf: messages)
        diagnostics.messageCount += messages.count
        diagnostics.lastMessageSent = messages.last?.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
