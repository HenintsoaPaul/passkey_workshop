import 'dart:convert';
import 'dart:math';

import 'package:basic_utils/basic_utils.dart' show CryptoUtils;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import 'key_storage.dart';
import 'signing_service.dart';

/// Pure-Dart fallback backend: the pair is generated with pointycastle and the
/// private PEM is held by [KeyStorage].
///
/// Used where [KeystoreSigningService] cannot run. The private key never
/// leaves the device, but unlike a Keystore key it does exist as bytes this
/// process can read, so the platform backend is preferred when available.
class LocalSigningService extends SigningService {
  LocalSigningService({KeyStorage? storage})
      : _storage = storage ?? const SecureKeyStorage();

  final KeyStorage _storage;

  static const privateKeyEntry = 'signing_private_key_pem';
  static const publicKeyEntry = 'signing_public_key_pem';

  static const keySize = 2048;

  @override
  String get backendLabel => 'Application (stockage sécurisé)';

  RSAPrivateKey? _privateKey;

  @override
  Future<bool> hasKeyPair() async =>
      await _storage.read(privateKeyEntry) != null;

  /// The public PEM to register with the server, generating the pair on first
  /// call. Generation is a few seconds of arithmetic, so it runs off the UI
  /// isolate.
  @override
  Future<String> ensurePublicKeyPem() async {
    final existing = await _storage.read(publicKeyEntry);

    if (existing != null) {
      return existing;
    }

    final pems = await compute(generateKeyPairPems, keySize);

    await _storage.write(privateKeyEntry, pems.privatePem);
    await _storage.write(publicKeyEntry, pems.publicPem);

    _privateKey = null;

    return pems.publicPem;
  }

  /// Sign a document with the device's private key.
  ///
  /// Takes the document bytes rather than a digest because PKCS#1 v1.5 signs
  /// `DigestInfo(SHA-256, H)`: the signer has to do the hashing itself for the
  /// structure to come out right. The value actually covered by the signature
  /// is still the SHA-256 digest, which is what the server verifies against
  /// with `Prehashed`.
  @override
  Future<String> signDocument(Uint8List bytes) async {
    final key = await _loadPrivateKey();

    if (key == null) {
      throw StateError(
        'Aucune clé de signature sur cet appareil.',
      );
    }

    final signer = RSASigner(SHA256Digest(), _sha256DigestIdentifier)
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(key));

    return base64.encode(signer.generateSignature(bytes).bytes);
  }

  /// Drop the pair, e.g. when signing out of an account for good.
  @override
  Future<void> reset() async {
    await _storage.delete(privateKeyEntry);
    await _storage.delete(publicKeyEntry);
    _privateKey = null;
  }

  Future<RSAPrivateKey?> _loadPrivateKey() async {
    if (_privateKey != null) {
      return _privateKey;
    }

    final pem = await _storage.read(privateKeyEntry);

    if (pem == null) {
      return null;
    }

    return _privateKey = CryptoUtils.rsaPrivateKeyFromPem(pem);
  }
}

/// DER-encoded OID of SHA-256, as pointycastle wants it for PKCS#1 v1.5.
const _sha256DigestIdentifier = '0609608648016503040201';

/// PEM pair returned from the generation isolate.
class KeyPairPems {
  const KeyPairPems(this.privatePem, this.publicPem);

  final String privatePem;
  final String publicPem;
}

/// Top-level so it can run under [compute].
KeyPairPems generateKeyPairPems(int keySize) {
  final random = Random.secure();

  final seed = Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );

  final secureRandom = FortunaRandom()..seed(KeyParameter(seed));

  final generator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), keySize, 64),
        secureRandom,
      ),
    );

  final pair = generator.generateKeyPair();

  return KeyPairPems(
    CryptoUtils.encodeRSAPrivateKeyToPem(pair.privateKey as RSAPrivateKey),
    CryptoUtils.encodeRSAPublicKeyToPem(pair.publicKey as RSAPublicKey),
  );
}
