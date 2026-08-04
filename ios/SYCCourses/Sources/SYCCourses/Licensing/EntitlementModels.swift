import Foundation

struct EntitlementEnvelope: Codable, Equatable, Sendable {
    let payload: String
    let signature: String
}

struct EntitlementPayload: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let entitlementId: String
    let clubId: String
    let permittedPackIds: [String]
    let installationId: String
    let entitlementType: EntitlementType
    let enabledFeatures: [String]
    let issuedAt: Date
    let refreshAfter: Date
    let expiresAt: Date?
    let graceUntil: Date?
    let perpetualAccess: Bool
    let keyId: String
}

enum EntitlementType: String, Codable, Sendable { case term, perpetual }

struct VerifiedEntitlement: Equatable, Sendable {
    let envelope: EntitlementEnvelope
    let payload: EntitlementPayload
}

enum AccessState: Equatable, Sendable {
    case noAccess
    case legacyBundledSnapshot
    case valid(VerifiedEntitlement)
    case refreshDue(VerifiedEntitlement)
    case gracePeriod(VerifiedEntitlement)
    case expired(VerifiedEntitlement)
    case invalid
    case temporarilyUnableToRefresh(VerifiedEntitlement, retryAt: Date)
}

extension AccessState {
    var retainsDownloadedReferenceAccess: Bool {
        switch self {
        case .legacyBundledSnapshot, .valid, .refreshDue, .gracePeriod, .expired, .temporarilyUnableToRefresh: true
        case .noAccess, .invalid: false
        }
    }

    var permitsCoursePackUpdates: Bool {
        switch self {
        case .valid(let entitlement), .refreshDue(let entitlement), .temporarilyUnableToRefresh(let entitlement, _):
            entitlement.payload.enabledFeatures.contains("coursePackUpdates")
        case .gracePeriod, .expired, .legacyBundledSnapshot, .noAccess, .invalid: false
        }
    }

    var needsRefresh: Bool {
        switch self {
        case .refreshDue, .gracePeriod, .expired, .temporarilyUnableToRefresh: true
        default: false
        }
    }
}

enum EntitlementVerificationError: Error, Equatable {
    case malformedEnvelope, unknownSchemaVersion, unknownKeyId, invalidSignature
    case installationMismatch, unexpectedClub, unpermittedPack, inconsistentDates, expiredBeyondGrace
}
