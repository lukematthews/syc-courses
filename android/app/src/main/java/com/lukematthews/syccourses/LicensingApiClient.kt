package com.lukematthews.syccourses

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.HttpURLConnection
import java.net.URL

@Serializable private data class ActivationRequest(val invitationCode: String, val installationId: String, val appVersion: String, val platform: String = "android")
@Serializable private data class RefreshRequest(val refreshCredential: String, val installationId: String, val appVersion: String)
@Serializable data class ActivationResponse(val entitlement: EntitlementEnvelope, val refreshCredential: String)
@Serializable data class RefreshResponse(val entitlement: EntitlementEnvelope)

class LicensingApiException(val code: String) : Exception(code)

class LicensingApiClient(private val endpoint: String, private val json: Json = Json { ignoreUnknownKeys = true }) {
    suspend fun activate(code: String, installationId: String, appVersion: String): ActivationResponse =
        post("v1/activations", json.encodeToString(ActivationRequest(code, installationId, appVersion)))

    suspend fun refresh(credential: String, installationId: String, appVersion: String): RefreshResponse =
        post("v1/entitlements/refresh", json.encodeToString(RefreshRequest(credential, installationId, appVersion)))

    private suspend inline fun <reified T> post(path: String, body: String): T = withContext(Dispatchers.IO) {
        val connection = URL("${endpoint.trimEnd('/')}/$path").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 15_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.use { it.write(body.encodeToByteArray()) }
            val stream = if (connection.responseCode in 200..299) connection.inputStream else connection.errorStream
            val responseBody = stream?.use { it.readBytes().decodeToString() }.orEmpty()
            if (connection.responseCode !in 200..299) {
                val code = runCatching { json.parseToJsonElement(responseBody).jsonObject["error"]!!.jsonObject["code"]!!.jsonPrimitive.content }.getOrNull()
                throw LicensingApiException(code ?: "TEMPORARY_SERVER_ERROR")
            }
            runCatching { json.decodeFromString<T>(responseBody) }.getOrElse { throw LicensingApiException("INVALID_RESPONSE") }
        } finally { connection.disconnect() }
    }
}
