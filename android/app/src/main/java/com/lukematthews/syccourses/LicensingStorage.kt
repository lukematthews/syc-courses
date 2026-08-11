package com.lukematthews.syccourses

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import android.util.Base64
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

interface SecureValueStore {
    fun get(key: String): String?
    fun set(key: String, value: String)
}

class AndroidKeystoreValueStore(context: Context) : SecureValueStore {
    private val preferences = context.getSharedPreferences("syc_licensing_secure", Context.MODE_PRIVATE)
    private val alias = "syc-licensing-values-v1"

    override fun get(key: String): String? {
        val encoded = preferences.getString(key, null) ?: return null
        return runCatching {
            val combined = Base64.decode(encoded, Base64.NO_WRAP)
            require(combined.size > 12)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, combined.copyOfRange(0, 12)))
            cipher.doFinal(combined.copyOfRange(12, combined.size)).decodeToString()
        }.getOrNull()
    }

    override fun set(key: String, value: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val encrypted = cipher.iv + cipher.doFinal(value.encodeToByteArray())
        check(preferences.edit().putString(key, Base64.encodeToString(encrypted, Base64.NO_WRAP)).commit())
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build())
        return generator.generateKey()
    }
}

class InstallationIdentityStore(private val storage: SecureValueStore) {
    fun identifier(): String {
        storage.get("installation-id-v1")?.takeIf { runCatching { UUID.fromString(it) }.isSuccess }?.let { return it }
        return UUID.randomUUID().toString().also { storage.set("installation-id-v1", it) }
    }
}

class RefreshCredentialStore(private val storage: SecureValueStore) {
    fun credential(): String? = storage.get("refresh-credential-v1")
    fun save(value: String) = storage.set("refresh-credential-v1", value)
}

interface EntitlementStore {
    fun load(): EntitlementEnvelope?
    fun save(value: EntitlementEnvelope)
}

class FileEntitlementStore(context: Context, private val json: Json = Json) : EntitlementStore {
    private val file = AtomicFile(File(context.noBackupFilesDir, "licensing/entitlement-v1.json").also { it.parentFile?.mkdirs() })

    override fun load(): EntitlementEnvelope? = if (!file.baseFile.exists()) null else
        file.openRead().use { json.decodeFromString<EntitlementEnvelope>(it.readBytes().decodeToString()) }

    override fun save(value: EntitlementEnvelope) {
        val output = file.startWrite()
        try {
            output.write(json.encodeToString(value).encodeToByteArray())
            file.finishWrite(output)
        } catch (error: Exception) {
            file.failWrite(output)
            throw error
        }
    }
}

class LegacyAccessMigrator(private val context: Context) {
    private val preferences = context.getSharedPreferences("syc_licensing_migration", Context.MODE_PRIVATE)
    fun hasLegacyBundledAccess(): Boolean {
        if (preferences.getInt("migration-version", 0) >= 1) return preferences.getBoolean("legacy-bundled-access", false)
        val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
        val upgradedInstallation = packageInfo.lastUpdateTime > packageInfo.firstInstallTime
        preferences.edit().putBoolean("legacy-bundled-access", upgradedInstallation).putInt("migration-version", 1).apply()
        return upgradedInstallation
    }
}
