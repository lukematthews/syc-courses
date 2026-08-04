import CryptoKit
import Foundation

struct EntitlementVerifier: Sendable {
    let publicKeys: [String: Data]

    func verify(
        _ envelope: EntitlementEnvelope,
        installationId: String,
        expectedClubId: String?,
        expectedPackId: String,
        now: Date,
        allowExpiredReferenceAccess: Bool = true
    ) throws -> VerifiedEntitlement {
        guard let payloadBytes = Data(base64URLEncoded: envelope.payload),
              let signature = Data(base64URLEncoded: envelope.signature)
        else { throw EntitlementVerificationError.malformedEnvelope }

        let decoder = JSONDecoder.licensing
        guard let payload = try? decoder.decode(EntitlementPayload.self, from: payloadBytes)
        else { throw EntitlementVerificationError.malformedEnvelope }
        guard payload.schemaVersion == 1 else { throw EntitlementVerificationError.unknownSchemaVersion }
        guard let keyBytes = publicKeys[payload.keyId] else { throw EntitlementVerificationError.unknownKeyId }
        let key: Curve25519.Signing.PublicKey
        do { key = try Curve25519.Signing.PublicKey(rawRepresentation: keyBytes) }
        catch { throw EntitlementVerificationError.unknownKeyId }
        guard key.isValidSignature(signature, for: payloadBytes) else { throw EntitlementVerificationError.invalidSignature }
        guard payload.installationId == installationId else { throw EntitlementVerificationError.installationMismatch }
        if let expectedClubId, payload.clubId != expectedClubId { throw EntitlementVerificationError.unexpectedClub }
        guard payload.permittedPackIds.contains(expectedPackId) else { throw EntitlementVerificationError.unpermittedPack }
        guard payload.refreshAfter >= payload.issuedAt,
              payload.issuedAt <= now.addingTimeInterval(5 * 60),
              payload.entitlementType == (payload.perpetualAccess ? .perpetual : .term),
              (payload.perpetualAccess ? payload.expiresAt == nil && payload.graceUntil == nil : payload.expiresAt != nil && payload.graceUntil != nil)
        else { throw EntitlementVerificationError.inconsistentDates }
        if let expires = payload.expiresAt, let grace = payload.graceUntil, grace < expires { throw EntitlementVerificationError.inconsistentDates }
        if !allowExpiredReferenceAccess, let boundary = payload.graceUntil ?? payload.expiresAt, now > boundary {
            throw EntitlementVerificationError.expiredBeyondGrace
        }
        return VerifiedEntitlement(envelope: envelope, payload: payload)
    }
}

extension Data {
    init?(base64URLEncoded value: String) {
        guard !value.isEmpty, value.range(of: "[^A-Za-z0-9_-]", options: .regularExpression) == nil else { return nil }
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }
}

extension JSONDecoder {
    static var licensing: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var licensing: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
