import XCTest
@testable import SYCCourses

@MainActor
final class NavigationDataTests: XCTestCase {
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
