import Foundation

struct AccessPolicyEvaluator: Sendable {
    func evaluate(_ entitlement: VerifiedEntitlement, now: Date) -> AccessState {
        let payload = entitlement.payload
        if payload.perpetualAccess {
            return now < payload.refreshAfter ? .valid(entitlement) : .refreshDue(entitlement)
        }
        if now < payload.refreshAfter { return .valid(entitlement) }
        if let expiresAt = payload.expiresAt, now < expiresAt { return .refreshDue(entitlement) }
        if let graceUntil = payload.graceUntil, now <= graceUntil { return .gracePeriod(entitlement) }
        return .expired(entitlement)
    }
}
