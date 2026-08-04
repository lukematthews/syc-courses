import CryptoKit
import Foundation
import XCTest
@testable import SYCCourses

final class LicensingTests: XCTestCase {
    private let privateKey = try! Curve25519.Signing.PrivateKey(rawRepresentation: Data(base64Encoded: "fp1LIk9++YzvU2xvbzhVAQHUbt2LGtRJJmS2uBUy7fI=")!) // TEST-ONLY key
    private let keyId = "test-key-1"
    private let installationId = "11111111-1111-4111-8111-111111111111"
    private let packId = "sandringham-yacht-club-2025-2028"
    private let clock = Date(timeIntervalSince1970: 1_800_000_000)

    func testInstallationIdentityIsCreatedAndPersists() throws {
        let secure = MemorySecureStore()
        let store = InstallationIdentityStore(storage: secure)
        let first = try store.identifier()
        XCTAssertEqual(first, try store.identifier())
        XCTAssertNotNil(UUID(uuidString: first))
    }

    func testValidSignatureAndPayloadAreAccepted() throws {
        let value = try verifier.verify(envelope(), installationId: installationId, expectedClubId: "syc", expectedPackId: packId, now: clock)
        XCTAssertEqual(value.payload.clubId, "syc")
    }

    func testTamperedPayloadAndSignatureAreRejected() {
        var value = envelope(); value = EntitlementEnvelope(payload: tamper(value.payload), signature: value.signature)
        XCTAssertThrowsError(try verify(value))
        let original = envelope(); XCTAssertThrowsError(try verify(EntitlementEnvelope(payload: original.payload, signature: tamper(original.signature))))
    }

    private func tamper(_ encoded: String) -> String {
        let replacement: Character = encoded.first == "A" ? "B" : "A"
        return String(replacement) + encoded.dropFirst()
    }

    func testUnknownKeyInstallationClubAndPackAreRejected() {
        XCTAssertThrowsError(try EntitlementVerifier(publicKeys: [:]).verify(envelope(), installationId: installationId, expectedClubId: "syc", expectedPackId: packId, now: clock))
        XCTAssertThrowsError(try verifier.verify(envelope(), installationId: "22222222-2222-4222-8222-222222222222", expectedClubId: "syc", expectedPackId: packId, now: clock))
        XCTAssertThrowsError(try verifier.verify(envelope(), installationId: installationId, expectedClubId: "other", expectedPackId: packId, now: clock))
        XCTAssertThrowsError(try verifier.verify(envelope(), installationId: installationId, expectedClubId: "syc", expectedPackId: "other-pack", now: clock))
    }

    func testAccessBoundaries() throws {
        let issued = clock; let verified = try verify(envelope(issued: issued, refresh: issued.addingTimeInterval(14 * 86_400), expiry: issued.addingTimeInterval(30 * 86_400), grace: issued.addingTimeInterval(60 * 86_400)))
        let policy = AccessPolicyEvaluator()
        guard case .valid = policy.evaluate(verified, now: issued.addingTimeInterval(14 * 86_400 - 1)) else { return XCTFail() }
        guard case .refreshDue = policy.evaluate(verified, now: issued.addingTimeInterval(14 * 86_400)) else { return XCTFail() }
        guard case .gracePeriod = policy.evaluate(verified, now: issued.addingTimeInterval(30 * 86_400)) else { return XCTFail() }
        guard case .gracePeriod = policy.evaluate(verified, now: issued.addingTimeInterval(60 * 86_400)) else { return XCTFail() }
        guard case .expired = policy.evaluate(verified, now: issued.addingTimeInterval(60 * 86_400 + 1)) else { return XCTFail() }
    }

    func testPerpetualEntitlementNeverCommerciallyExpiresButRefreshes() throws {
        let verified = try verify(envelope(expiry: nil, grace: nil, perpetual: true))
        guard case .refreshDue = AccessPolicyEvaluator().evaluate(verified, now: clock.addingTimeInterval(20 * 86_400)) else { return XCTFail() }
        XCTAssertTrue(AccessPolicyEvaluator().evaluate(verified, now: clock.addingTimeInterval(20 * 86_400)).retainsDownloadedReferenceAccess)
    }

    func testAtomicEntitlementReplacementAndCorruption() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = EntitlementStore(fileURL: directory.appendingPathComponent("value.json"))
        let first = envelope(); try store.save(first); XCTAssertEqual(try store.load(), first)
        let second = envelope(issued: clock.addingTimeInterval(1)); try store.save(second); XCTAssertEqual(try store.load(), second)
        try Data("broken".utf8).write(to: store.fileURL); XCTAssertThrowsError(try store.load())
    }

    func testLegacyMigrationLockedUnlockedAlreadyMigratedAndMalformed() throws {
        let suite = "LegacyMigrationTests-\(UUID())"; let defaults = UserDefaults(suiteName: suite)!; defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.json")
        let migrator = LegacyAccessMigrator(defaults: defaults, recordURL: url, now: { self.clock })
        XCTAssertNil(migrator.migrateIfNeeded(packId: packId))
        defaults.set(true, forKey: LegacyAccessMigrator.oldUnlockedKey)
        XCTAssertEqual(migrator.migrateIfNeeded(packId: packId)?.packId, packId)
        XCTAssertNil(defaults.object(forKey: LegacyAccessMigrator.oldUnlockedKey))
        XCTAssertEqual(migrator.migrateIfNeeded(packId: packId)?.migratedAt, clock)
        try Data("malformed".utf8).write(to: url, options: .atomic); defaults.set(true, forKey: LegacyAccessMigrator.oldUnlockedKey)
        XCTAssertEqual(migrator.migrateIfNeeded(packId: packId)?.packId, packId)
    }

    func testFreshInstallHasNoUniversalCodePath() {
        XCTAssertFalse(String(describing: ClubAccessStore.self).contains("SYC-TRIAL-26"))
    }

    private var verifier: EntitlementVerifier { EntitlementVerifier(publicKeys: [keyId: privateKey.publicKey.rawRepresentation]) }
    private func verify(_ value: EntitlementEnvelope) throws -> VerifiedEntitlement { try verifier.verify(value, installationId: installationId, expectedClubId: "syc", expectedPackId: packId, now: clock) }
    private func envelope(issued: Date? = nil, refresh: Date? = nil, expiry: Date? = nil, grace: Date? = nil, perpetual: Bool = false) -> EntitlementEnvelope {
        let issued = issued ?? clock.addingTimeInterval(-86_400); let refresh = refresh ?? issued.addingTimeInterval(14 * 86_400)
        let payload = EntitlementPayload(schemaVersion: 1, entitlementId: UUID().uuidString, clubId: "syc", permittedPackIds: [packId], installationId: installationId, entitlementType: perpetual ? .perpetual : .term, enabledFeatures: ["coursePackUpdates"], issuedAt: issued, refreshAfter: refresh, expiresAt: perpetual ? nil : (expiry ?? issued.addingTimeInterval(30 * 86_400)), graceUntil: perpetual ? nil : (grace ?? issued.addingTimeInterval(60 * 86_400)), perpetualAccess: perpetual, keyId: keyId)
        let bytes = try! JSONEncoder.licensing.encode(payload); let signature = try! privateKey.signature(for: bytes)
        return EntitlementEnvelope(payload: bytes.base64URLEncodedString(), signature: signature.base64URLEncodedString())
    }
}

private final class MemorySecureStore: SecureValueStoring, @unchecked Sendable {
    private var values: [String: Data] = [:]
    func data(for key: String) throws -> Data? { values[key] }
    func set(_ data: Data, for key: String) throws { values[key] = data }
}

private extension Data {
    func base64URLEncodedString() -> String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}
