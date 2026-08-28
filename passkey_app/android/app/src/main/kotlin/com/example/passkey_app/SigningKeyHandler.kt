package com.example.passkey_app

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature

/**
 * Generates and uses the document-signing RSA key inside the Android Keystore.
 *
 * §2.2 of the TP requires the private key to stay on the device. Generated
 * here it is stronger than that: the key material is created by the Keystore
 * and is never exportable, so no code path — not even this one — can read it
 * back. Only the public key and the signatures ever leave.
 */
class SigningKeyHandler : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "passkey_app/signing_key"

        private const val ALIAS = "passkey_app_document_signing_key"
        private const val PROVIDER = "AndroidKeyStore"

        /** PKCS#1 v1.5 over SHA-256: what the Django side verifies. */
        private const val SIGNATURE_ALGORITHM = "SHA256withRSA"
    }

    private fun keyStore(): KeyStore = KeyStore.getInstance(PROVIDER).apply { load(null) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isAvailable" -> result.success(true)
                "hasKeyPair" -> result.success(keyStore().containsAlias(ALIAS))
                "publicKeyPem" -> result.success(publicKeyPem())
                "generate" -> result.success(generate())
                "sign" -> {
                    val bytes = call.argument<ByteArray>("bytes")

                    if (bytes == null) {
                        result.error("invalid_argument", "bytes manquant", null)
                    } else {
                        result.success(sign(bytes))
                    }
                }
                "delete" -> {
                    keyStore().deleteEntry(ALIAS)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("keystore_error", error.message, null)
        }
    }

    private fun generate(): String {
        val store = keyStore()

        if (store.containsAlias(ALIAS)) {
            store.deleteEntry(ALIAS)
        }

        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, PROVIDER)

        // setUserAuthenticationRequired is deliberately not set: the passkey
        // assertion demanded immediately before every signature already proves
        // the user is present, and a second biometric prompt on top of it
        // would only add friction. The key stays non-exportable either way.
        generator.initialize(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_SIGN)
                .setKeySize(2048)
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1)
                .build()
        )

        generator.generateKeyPair()

        return publicKeyPem() ?: throw IllegalStateException("Clé générée mais illisible.")
    }

    /** SubjectPublicKeyInfo DER, wrapped as PEM — the shape Django expects. */
    private fun publicKeyPem(): String? {
        val certificate = keyStore().getCertificate(ALIAS) ?: return null
        val body = Base64.encodeToString(certificate.publicKey.encoded, Base64.NO_WRAP)

        return buildString {
            append("-----BEGIN PUBLIC KEY-----\n")
            body.chunked(64).forEach { append(it).append("\n") }
            append("-----END PUBLIC KEY-----")
        }
    }

    private fun sign(bytes: ByteArray): ByteArray {
        val entry = keyStore().getEntry(ALIAS, null) as? KeyStore.PrivateKeyEntry
            ?: throw IllegalStateException("Aucune clé de signature dans le Keystore.")

        return Signature.getInstance(SIGNATURE_ALGORITHM).run {
            initSign(entry.privateKey)
            update(bytes)
            sign()
        }
    }
}
