package com.lukematthews.syccourses

import kotlinx.serialization.Serializable
import java.time.Instant

@Serializable
data class EntitlementEnvelope(val payload: String, val signature: String)

@Serializable
data class EntitlementPayload(
    val schemaVersion: Int,
    val entitlementId: String,
    val clubId: String,
    val permittedPackIds: List<String>,
    val installationId: String,
    val entitlementType: String,
    val enabledFeatures: List<String>,
    val issuedAt: String,
    val refreshAfter: String,
    val expiresAt: String?,
    val graceUntil: String?,
    val perpetualAccess: Boolean,
    val keyId: String,
)

data class VerifiedEntitlement(
    val envelope: EntitlementEnvelope,
    val payload: EntitlementPayload,
    val issuedAt: Instant,
    val refreshAfter: Instant,
    val expiresAt: Instant?,
    val graceUntil: Instant?,
)

sealed interface ClubAccessState {
    data object Loading : ClubAccessState
    data object NoAccess : ClubAccessState
    data object LegacyBundledSnapshot : ClubAccessState
    data object Invalid : ClubAccessState
    data class Valid(val entitlement: VerifiedEntitlement) : ClubAccessState
    data class RefreshDue(val entitlement: VerifiedEntitlement) : ClubAccessState
    data class GracePeriod(val entitlement: VerifiedEntitlement) : ClubAccessState
    data class Expired(val entitlement: VerifiedEntitlement) : ClubAccessState
    data class TemporarilyUnableToRefresh(val entitlement: VerifiedEntitlement, val retryAt: Instant) : ClubAccessState
}

val ClubAccessState.retainsBundledReferenceAccess: Boolean
    get() = this !is ClubAccessState.Loading && this !is ClubAccessState.NoAccess && this !is ClubAccessState.Invalid

val ClubAccessState.needsRefresh: Boolean
    get() = this is ClubAccessState.RefreshDue || this is ClubAccessState.GracePeriod ||
        this is ClubAccessState.Expired || this is ClubAccessState.TemporarilyUnableToRefresh

val ClubAccessState.statusMessage: String?
    get() = when (this) {
        is ClubAccessState.LegacyBundledSnapshot -> "Legacy access: bundled SYC course snapshot only."
        is ClubAccessState.GracePeriod -> "Unable to confirm updates. Bundled course information remains available."
        is ClubAccessState.Expired -> "Club access has expired. Bundled reference information may no longer be current."
        is ClubAccessState.TemporarilyUnableToRefresh -> "Unable to refresh right now. Bundled course information remains available."
        else -> null
    }

object AccessPolicyEvaluator {
    fun evaluate(entitlement: VerifiedEntitlement, now: Instant): ClubAccessState {
        if (entitlement.payload.perpetualAccess) {
            return if (now < entitlement.refreshAfter) ClubAccessState.Valid(entitlement) else ClubAccessState.RefreshDue(entitlement)
        }
        if (now < entitlement.refreshAfter) return ClubAccessState.Valid(entitlement)
        if (entitlement.expiresAt?.let { now < it } == true) return ClubAccessState.RefreshDue(entitlement)
        if (entitlement.graceUntil?.let { now <= it } == true) return ClubAccessState.GracePeriod(entitlement)
        return ClubAccessState.Expired(entitlement)
    }
}
