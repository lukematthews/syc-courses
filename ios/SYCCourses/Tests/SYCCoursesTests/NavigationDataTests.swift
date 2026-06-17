#if canImport(XCTest)
@testable import SYCCourses
import XCTest

@MainActor
final class NavigationDataTests: XCTestCase {
    func testRMCParsing() {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        let update = NMEASentenceParser.parse("$GPRMC,092751.000,A,3756.8100,S,14459.4000,E,6.2,185.5,160626,,,A*00", now: now)

        XCTAssertEqual(update?.fix?.latitude ?? 0, -37.946833, accuracy: 0.00001)
        XCTAssertEqual(update?.fix?.longitude ?? 0, 144.99, accuracy: 0.00001)
        XCTAssertEqual(update?.fix?.sogKnots, 6.2)
        XCTAssertEqual(update?.fix?.cogDegrees, 185.5)
        XCTAssertEqual(update?.fix?.validFix, true)
    }

    func testGGAParsing() {
        let update = NMEASentenceParser.parse("$GPGGA,092751.000,3756.8100,S,14459.4000,E,1,08,0.9,0.0,M,0.0,M,,*00")

        XCTAssertEqual(update?.fix?.latitude ?? 0, -37.946833, accuracy: 0.00001)
        XCTAssertEqual(update?.fix?.longitude ?? 0, 144.99, accuracy: 0.00001)
        XCTAssertEqual(update?.fix?.validFix, true)
        XCTAssertEqual(update?.fix?.hdop, 0.9)
    }

    func testVTGParsing() {
        let update = NMEASentenceParser.parse("$GPVTG,185.5,T,,M,6.2,N,11.5,K,A*00")

        XCTAssertEqual(update?.cogDegrees, 185.5)
        XCTAssertEqual(update?.sogKnots, 6.2)
    }

    func testHeadingParsing() {
        XCTAssertEqual(NMEASentenceParser.parse("$GPHDT,183.2,T*00")?.headingDegrees, 183.2)
        XCTAssertEqual(NMEASentenceParser.parse("$GPHDM,181.0,M*00")?.headingDegrees, 181.0)
        XCTAssertEqual(NMEASentenceParser.parse("$HCHDG,179.8,,,,*00")?.headingDegrees, 179.8)
    }

    func testFallsBackToIPhoneWhenActisenseStale() {
        let provider = ActisenseNMEAProvider()
        let service = makeService(provider: provider, staleAfterSeconds: 5)
        let old = Date(timeIntervalSinceReferenceDate: 0)
        provider.ingest(sentence: "$GPRMC,000000.000,A,3756.8100,S,14459.4000,E,7.0,180.0,010101,,,A*00", now: old)

        let iPhoneFix = NavigationFix(
            latitude: -37.95,
            longitude: 145.0,
            sogKnots: 4.0,
            cogDegrees: nil,
            headingDegrees: nil,
            timestamp: old.addingTimeInterval(10),
            source: .iPhoneGPS,
            horizontalAccuracyMeters: 5,
            hdop: nil,
            validFix: true
        )

        let active = service.activeFix(iPhoneFix: iPhoneFix, now: old.addingTimeInterval(10))
        XCTAssertEqual(active?.source, .iPhoneGPS)
    }

    func testPrefersFreshActisenseFix() {
        let provider = ActisenseNMEAProvider()
        let service = makeService(provider: provider)
        let now = freshNMEADate()
        provider.ingest(sentence: "$GPRMC,000000.000,A,3756.8100,S,14459.4000,E,7.0,180.0,160626,,,A*00", now: now)

        let active = service.activeFix(iPhoneFix: iPhoneFix(timestamp: now), now: now)

        XCTAssertEqual(active?.source, .actisense)
        XCTAssertEqual(active?.sogKnots, 7.0)
    }

    func testStartAssistUsesActiveSourceSOG() {
        let provider = ActisenseNMEAProvider()
        let service = makeService(provider: provider)
        let now = freshNMEADate()
        provider.ingest(sentence: "$GPRMC,000000.000,A,3756.8100,S,14459.4000,E,8.0,180.0,160626,,,A*00", now: now)
        let mark = Mark(
            id: "target",
            name: "Target",
            aliases: [],
            latitude: -37.963333,
            longitude: 144.9815,
            description: nil,
            coordinatesStatus: "test"
        )

        let snapshot = service.snapshot(to: mark, iPhoneFix: iPhoneFix(timestamp: now, sog: 2.0), now: now)

        XCTAssertEqual(snapshot?.speedOverGroundKnots, 8.0)
        XCTAssertEqual(snapshot?.timeToMark ?? 0, ((snapshot?.distanceNm ?? 0) / 8.0) * 3600, accuracy: 0.0001)
    }

    private func makeService(provider: ActisenseNMEAProvider, staleAfterSeconds: TimeInterval = 5) -> NavigationDataService {
        let defaults = UserDefaults(suiteName: "NavigationDataTests-\(UUID().uuidString)")!
        let service = NavigationDataService(defaults: defaults, actisenseProvider: provider)
        service.actisenseConfig = ActisenseInputConfig(
            isEnabled: true,
            host: "192.168.4.1",
            port: 60001,
            networkProtocol: .tcp,
            staleAfterSeconds: staleAfterSeconds
        )
        return service
    }

    private func iPhoneFix(timestamp: Date, sog: Double = 4.0) -> NavigationFix {
        NavigationFix(
            latitude: -37.95,
            longitude: 145.0,
            sogKnots: sog,
            cogDegrees: nil,
            headingDegrees: nil,
            timestamp: timestamp,
            source: .iPhoneGPS,
            horizontalAccuracyMeters: 5,
            hdop: nil,
            validFix: true
        )
    }

    private func freshNMEADate() -> Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 16,
            hour: 0,
            minute: 0,
            second: 0
        ).date!
    }
}
#endif
