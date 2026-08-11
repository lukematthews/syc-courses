package com.lukematthews.syccourses

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test
import java.time.Instant
import java.util.Base64

class LicensingTest {
    private val installationId = "11111111-1111-4111-8111-111111111111"
    private val packId = "sandringham-yacht-club-2025-2028"
    private val publicKey = Base64.getDecoder().decode("k7VZdCb11rwBTsDXUReBN/UUA3QqkM7ZeRnZupVk8hc=")
    private val envelope = EntitlementEnvelope(
        payload = "eyJzY2hlbWFWZXJzaW9uIjoxLCJlbnRpdGxlbWVudElkIjoiZW50aXRsZW1lbnQtdGVzdC0xIiwiY2x1YklkIjoic3ljIiwicGVybWl0dGVkUGFja0lkcyI6WyJzYW5kcmluZ2hhbS15YWNodC1jbHViLTIwMjUtMjAyOCJdLCJpbnN0YWxsYXRpb25JZCI6IjExMTExMTExLTExMTEtNDExMS04MTExLTExMTExMTExMTExMSIsImVudGl0bGVtZW50VHlwZSI6InRlcm0iLCJlbmFibGVkRmVhdHVyZXMiOlsiY291cnNlUGFja1VwZGF0ZXMiXSwiaXNzdWVkQXQiOiIyMDI3LTAxLTE1VDA4OjAwOjAwWiIsInJlZnJlc2hBZnRlciI6IjIwMjctMDEtMjlUMDg6MDA6MDBaIiwiZXhwaXJlc0F0IjoiMjAyNy0wMi0xNFQwODowMDowMFoiLCJncmFjZVVudGlsIjoiMjAyNy0wMy0xNlQwODowMDowMFoiLCJwZXJwZXR1YWxBY2Nlc3MiOmZhbHNlLCJrZXlJZCI6ImNyb3NzLXBsYXRmb3JtLXRlc3QtMSJ9",
        signature = "fg0RvhQaoc2CESTUUtsYkTFixc0sqQ71XuvUpwwAR7_55lrsIW6UDE3Xxh-7QK1PYwcoHiXrru8Y9WGoqwDxAg",
    )
    private val verifier = EntitlementVerifier(mapOf("cross-platform-test-1" to publicKey))

    @Test fun verifiesServerCompatibleEd25519Envelope() {
        val verified = verifier.verify(envelope, installationId, "syc", packId, Instant.parse("2027-01-20T08:00:00Z"))
        assertEquals("syc", verified.payload.clubId)
        assertTrue(AccessPolicyEvaluator.evaluate(verified, Instant.parse("2027-01-20T08:00:00Z")) is ClubAccessState.Valid)
    }

    @Test fun rejectsTamperingAndWrongBinding() {
        val tampered = envelope.copy(payload = (if (envelope.payload.first() == 'A') "B" else "A") + envelope.payload.drop(1))
        assertThrows(EntitlementVerificationException::class.java) { verifier.verify(tampered, installationId, "syc", packId, Instant.parse("2027-01-20T08:00:00Z")) }
        assertThrows(EntitlementVerificationException::class.java) { verifier.verify(envelope, "22222222-2222-4222-8222-222222222222", "syc", packId, Instant.parse("2027-01-20T08:00:00Z")) }
        assertThrows(EntitlementVerificationException::class.java) { verifier.verify(envelope, installationId, "syc", "other-pack", Instant.parse("2027-01-20T08:00:00Z")) }
    }

    @Test fun appliesRefreshExpiryAndGraceBoundaries() {
        val verified = verifier.verify(envelope, installationId, "syc", packId, Instant.parse("2027-01-20T08:00:00Z"))
        assertTrue(AccessPolicyEvaluator.evaluate(verified, Instant.parse("2027-01-29T08:00:00Z")) is ClubAccessState.RefreshDue)
        assertTrue(AccessPolicyEvaluator.evaluate(verified, Instant.parse("2027-02-14T08:00:00Z")) is ClubAccessState.GracePeriod)
        assertTrue(AccessPolicyEvaluator.evaluate(verified, Instant.parse("2027-03-16T08:00:00Z")) is ClubAccessState.GracePeriod)
        assertTrue(AccessPolicyEvaluator.evaluate(verified, Instant.parse("2027-03-16T08:00:01Z")) is ClubAccessState.Expired)
    }

    @Test fun installationIdentityPersists() {
        val storage = MemorySecureValueStore()
        val first = InstallationIdentityStore(storage).identifier()
        assertEquals(first, InstallationIdentityStore(storage).identifier())
        assertTrue(runCatching { java.util.UUID.fromString(first) }.isSuccess)
    }

    @Test fun perpetualAccessNeverCommerciallyExpiresButBecomesRefreshDue() {
        val payload = EntitlementPayload(
            schemaVersion = 1, entitlementId = "perpetual-1", clubId = "syc", permittedPackIds = listOf(packId),
            installationId = installationId, entitlementType = "perpetual", enabledFeatures = emptyList(),
            issuedAt = "2027-01-01T00:00:00Z", refreshAfter = "2027-01-15T00:00:00Z",
            expiresAt = null, graceUntil = null, perpetualAccess = true, keyId = "unused",
        )
        val value = VerifiedEntitlement(
            EntitlementEnvelope("unused", "unused"), payload, Instant.parse(payload.issuedAt),
            Instant.parse(payload.refreshAfter), null, null,
        )
        assertTrue(AccessPolicyEvaluator.evaluate(value, Instant.parse("2040-01-01T00:00:00Z")) is ClubAccessState.RefreshDue)
        assertTrue(AccessPolicyEvaluator.evaluate(value, Instant.parse("2040-01-01T00:00:00Z")).retainsBundledReferenceAccess)
    }
}

private class MemorySecureValueStore : SecureValueStore {
    private val values = mutableMapOf<String, String>()
    override fun get(key: String): String? = values[key]
    override fun set(key: String, value: String) { values[key] = value }
}
