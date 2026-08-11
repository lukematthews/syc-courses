package com.lukematthews.syccourses

import android.content.Context
import android.util.Base64
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Clock
import java.time.Instant
import kotlin.math.min

class ClubAccessManager(
    context: Context,
    private val expectedPackId: String,
    private val clock: Clock = Clock.systemUTC(),
    private val secureStorage: SecureValueStore = AndroidKeystoreValueStore(context),
    private val entitlementStore: EntitlementStore = FileEntitlementStore(context),
    private val migrator: LegacyAccessMigrator = LegacyAccessMigrator(context),
    private val api: LicensingApiClient = LicensingApiClient(BuildConfig.LICENSING_API_ENDPOINT),
    publicKeys: Map<String, ByteArray> = mapOf(BuildConfig.LICENSING_KEY_ID to Base64.decode(BuildConfig.LICENSING_PUBLIC_KEY_BASE64, Base64.DEFAULT)),
) {
    private val identityStore = InstallationIdentityStore(secureStorage)
    private val credentialStore = RefreshCredentialStore(secureStorage)
    private val verifier = EntitlementVerifier(publicKeys)
    private val _state = MutableStateFlow<ClubAccessState>(ClubAccessState.Loading)
    private val _working = MutableStateFlow(false)
    private val _message = MutableStateFlow<String?>(null)
    val state = _state.asStateFlow()
    val working = _working.asStateFlow()
    val message = _message.asStateFlow()
    private var retryCount = 0
    private var nextAttemptAt: Instant? = null

    init { loadLocalAccess() }

    suspend fun activate(invitationCode: String) {
        if (_working.value) return
        _working.value = true
        _message.value = null
        try {
            val installationId = identityStore.identifier()
            val response = api.activate(invitationCode.trim(), installationId, BuildConfig.VERSION_NAME)
            val verified = verifier.verify(response.entitlement, installationId, null, expectedPackId, clock.instant(), false)
            entitlementStore.save(response.entitlement)
            credentialStore.save(response.refreshCredential)
            _state.value = AccessPolicyEvaluator.evaluate(verified, clock.instant())
            retryCount = 0
            nextAttemptAt = null
        } catch (error: Exception) {
            _message.value = activationMessage(error)
        } finally { _working.value = false }
    }

    suspend fun refreshIfDue() {
        if (!_state.value.needsRefresh || _working.value || nextAttemptAt?.let { clock.instant() < it } == true) return
        refresh(false)
    }

    suspend fun retryRefresh() = refresh(true)

    private suspend fun refresh(explicit: Boolean) {
        if (_working.value) return
        _working.value = true
        _message.value = null
        try {
            val credential = credentialStore.credential() ?: throw LicensingApiException("INVALID_RESPONSE")
            val installationId = identityStore.identifier()
            val response = api.refresh(credential, installationId, BuildConfig.VERSION_NAME)
            val verified = verifier.verify(response.entitlement, installationId, null, expectedPackId, clock.instant(), false)
            entitlementStore.save(response.entitlement)
            _state.value = AccessPolicyEvaluator.evaluate(verified, clock.instant())
            retryCount = 0
            nextAttemptAt = null
        } catch (_: Exception) {
            retryCount += 1
            val delaySeconds = min(24 * 60 * 60L, 15 * 60L * (1L shl min(retryCount - 1, 6)))
            nextAttemptAt = clock.instant().plusSeconds(delaySeconds)
            val entitlement = when (val current = _state.value) {
                is ClubAccessState.Valid -> current.entitlement
                is ClubAccessState.RefreshDue -> current.entitlement
                is ClubAccessState.GracePeriod -> current.entitlement
                is ClubAccessState.Expired -> current.entitlement
                is ClubAccessState.TemporarilyUnableToRefresh -> current.entitlement
                else -> null
            }
            if (entitlement != null) _state.value = ClubAccessState.TemporarilyUnableToRefresh(entitlement, nextAttemptAt!!)
            if (explicit) _message.value = "Unable to refresh right now. Bundled course information remains available."
        } finally { _working.value = false }
    }

    private fun loadLocalAccess() {
        val envelope = try { entitlementStore.load() } catch (_: Exception) { _state.value = ClubAccessState.Invalid; return }
        if (envelope != null) {
            try {
                val verified = verifier.verify(envelope, identityStore.identifier(), null, expectedPackId, clock.instant())
                _state.value = AccessPolicyEvaluator.evaluate(verified, clock.instant())
                return
            } catch (_: Exception) { _state.value = ClubAccessState.Invalid; return }
        }
        _state.value = if (migrator.hasLegacyBundledAccess()) ClubAccessState.LegacyBundledSnapshot else ClubAccessState.NoAccess
    }

    private fun activationMessage(error: Exception): String = when ((error as? LicensingApiException)?.code) {
        "INVALID_INVITATION", "INVITATION_INACTIVE", "INVITATION_EXPIRED" -> "That club invitation cannot be used. Ask your club for a current invitation."
        "RATE_LIMITED" -> "Too many attempts. Please wait before trying again."
        "UNSUPPORTED_APP_VERSION" -> "Update the app before activating."
        "MALFORMED_REQUEST" -> "The app's licensing configuration is invalid. Check the app version and try again."
        else -> "Unable to contact the club licensing service. Check your connection and try again."
    }
}
