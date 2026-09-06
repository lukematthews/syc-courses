import XCTest
@testable import SYCCourses

@MainActor
final class NavigationDataTests: XCTestCase {
    @MainActor
    func testStaleRefreshPublishesWithoutRecursiveReentry() async {
        let provider = ActisenseNMEAProvider(config: ActisenseInputConfig(staleAfterSeconds: 1))
        provider.ingest(
            sentence: "$GPGGA,092751.000,3756.8100,S,14459.4000,E,1,08,0.9,0.0,M,0.0,M,,*00",
            now: Date(timeIntervalSinceReferenceDate: 0)
        )

        let staleAt = provider.latestFix!.timestamp.addingTimeInterval(10)
        provider.refreshFreshness(now: staleAt)
        for _ in 0..<20 where provider.status != .stale {
            try? await Task.sleep(for: .milliseconds(1))
        }

        XCTAssertEqual(provider.status, .stale)
    }

    func testUsesUsableIPhoneGPSFix() {
        let service = NavigationDataService()
        let fix = makeFix()

        XCTAssertEqual(service.activeFix(iPhoneFix: fix), fix)
        XCTAssertEqual(service.sourceSummary(iPhoneFix: fix).activeSource, .iPhoneGPS)
    }

    func testRejectsInvalidIPhoneGPSFix() {
        let service = NavigationDataService()
        let invalidFix = makeFix(latitude: 100)

        XCTAssertNil(service.activeFix(iPhoneFix: invalidFix))
        XCTAssertEqual(service.sourceSummary(iPhoneFix: invalidFix).statusMessage, "No valid position")
    }

    func testNMEAInputRemainsOwnedUntilLastNavigationFeatureStops() {
        let service = NavigationDataService()

        service.startNavigationInput(for: .activeCourse)
        service.startNavigationInput(for: .quickBearing)

        service.stopNavigationInput(for: .quickBearing)
        XCTAssertTrue(service.isNavigationInputActive(for: .activeCourse))
        XCTAssertFalse(service.isNavigationInputActive(for: .quickBearing))

        service.stopNavigationInput(for: .activeCourse)
        XCTAssertFalse(service.isNavigationInputActive(for: .activeCourse))
        XCTAssertEqual(service.actisenseStatus, .disconnected)
    }

    func testStoppingAbsentInputOwnerDoesNotRepublishProviderState() {
        let provider = ActisenseNMEAProvider()
        let service = NavigationDataService(actisenseProvider: provider)
        var publicationCount = 0
        let cancellable = provider.objectWillChange.sink { publicationCount += 1 }

        service.stopNavigationInput(for: .activeCourse)

        XCTAssertEqual(publicationCount, 0)
        withExtendedLifetime(cancellable) {}
    }

    func testManualInputDisconnectBlocksOwnerDrivenReconnect() {
        let service = NavigationDataService()

        service.startNavigationInput(for: .activeCourse)
        service.disconnectActisense()
        service.startNavigationInput(for: .activeCourse)

        XCTAssertTrue(service.isManuallyDisconnected)
        XCTAssertTrue(service.isNavigationInputActive(for: .activeCourse))
        XCTAssertEqual(service.actisenseStatus, .disconnected)
    }

    private func makeFix(latitude: Double = -37.95) -> NavigationFix {
        NavigationFix(
            latitude: latitude,
            longitude: 145.0,
            sogKnots: 6,
            cogDegrees: 180,
            headingDegrees: nil,
            timestamp: Date(),
            source: .iPhoneGPS,
            horizontalAccuracyMeters: 5,
            hdop: nil,
            validFix: true
        )
    }
}
