package com.lukematthews.syccourses

import com.google.crypto.tink.subtle.Ed25519Verify
import kotlinx.serialization.json.Json
import java.time.Instant
import java.util.Base64

enum class EntitlementVerificationError { MALFORMED, UNKNOWN_SCHEMA, UNKNOWN_KEY, INVALID_SIGNATURE, INSTALLATION_MISMATCH, UNEXPECTED_CLUB, UNPERMITTED_PACK, INCONSISTENT_DATES, EXPIRED }
class EntitlementVerificationException(val reason: EntitlementVerificationError) : Exception(reason.name)

class EntitlementVerifier(
    private val publicKeys: Map<String, ByteArray>,
    private val json: Json = Json { ignoreUnknownKeys = true },
) {
    fun verify(
        envelope: EntitlementEnvelope,
        installationId: String,
        expectedClubId: String?,
        expectedPackId: String,
        now: Instant,
        allowExpiredReferenceAccess: Boolean = true,
    ): VerifiedEntitlement {
        val payloadBytes = decodeBase64Url(envelope.payload)
        val signature = decodeBase64Url(envelope.signature)
        val payload = runCatching { json.decodeFromString<EntitlementPayload>(payloadBytes.decodeToString()) }
            .getOrElse { throw EntitlementVerificationException(EntitlementVerificationError.MALFORMED) }
        if (payload.schemaVersion != 1) throw EntitlementVerificationException(EntitlementVerificationError.UNKNOWN_SCHEMA)
        val key = publicKeys[payload.keyId] ?: throw EntitlementVerificationException(EntitlementVerificationError.UNKNOWN_KEY)
        try { Ed25519Verify(key).verify(signature, payloadBytes) }
        catch (_: Exception) { throw EntitlementVerificationException(EntitlementVerificationError.INVALID_SIGNATURE) }
        if (payload.installationId != installationId) throw EntitlementVerificationException(EntitlementVerificationError.INSTALLATION_MISMATCH)
        if (expectedClubId != null && payload.clubId != expectedClubId) throw EntitlementVerificationException(EntitlementVerificationError.UNEXPECTED_CLUB)
        if (expectedPackId !in payload.permittedPackIds) throw EntitlementVerificationException(EntitlementVerificationError.UNPERMITTED_PACK)
        val issuedAt = parseInstant(payload.issuedAt)
        val refreshAfter = parseInstant(payload.refreshAfter)
        val expiresAt = payload.expiresAt?.let(::parseInstant)
        val graceUntil = payload.graceUntil?.let(::parseInstant)
        val correctType = payload.entitlementType == if (payload.perpetualAccess) "perpetual" else "term"
        val correctBoundaries = if (payload.perpetualAccess) expiresAt == null && graceUntil == null else expiresAt != null && graceUntil != null
        if (refreshAfter < issuedAt || issuedAt > now.plusSeconds(300) || !correctType || !correctBoundaries ||
            (expiresAt != null && graceUntil != null && graceUntil < expiresAt)) {
            throw EntitlementVerificationException(EntitlementVerificationError.INCONSISTENT_DATES)
        }
        if (!allowExpiredReferenceAccess && now > (graceUntil ?: expiresAt ?: Instant.MAX)) {
            throw EntitlementVerificationException(EntitlementVerificationError.EXPIRED)
        }
        return VerifiedEntitlement(envelope, payload, issuedAt, refreshAfter, expiresAt, graceUntil)
    }

    private fun decodeBase64Url(value: String): ByteArray {
        if (value.isEmpty() || !value.matches(Regex("[A-Za-z0-9_-]+"))) throw EntitlementVerificationException(EntitlementVerificationError.MALFORMED)
        return try { Base64.getUrlDecoder().decode(value) }
        catch (_: IllegalArgumentException) { throw EntitlementVerificationException(EntitlementVerificationError.MALFORMED) }
    }

    private fun parseInstant(value: String): Instant = runCatching { Instant.parse(value) }
        .getOrElse { throw EntitlementVerificationException(EntitlementVerificationError.INCONSISTENT_DATES) }
}
