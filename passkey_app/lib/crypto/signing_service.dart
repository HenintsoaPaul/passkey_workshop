import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'key_storage.dart';
import 'keystore_signing_service.dart';
import 'local_signing_service.dart';

/// The device's RSA identity: holds the private key, and signs documents.
///
/// §2.2 of the TP: the private key must stay on the phone. Nothing here ever
/// returns it — the only values that leave are [ensurePublicKeyPem] and the
/// signatures themselves.
///
/// Two backends implement this. [KeystoreSigningService] keeps the key in
/// Android's hardware-backed Keystore, where it is not exportable at all;
/// [LocalSigningService] is the pure-Dart fallback for everywhere else.
abstract class SigningService {
  const SigningService();
  /// Whether this device already has a key pair.
  Future<bool> hasKeyPair();

  /// The public PEM to register with the server, generating the pair on the
  /// first call.
  Future<String> ensurePublicKeyPem();

  /// Sign a document with the device's private key.
  ///
  /// Takes the document bytes rather than a digest because PKCS#1 v1.5 signs
  /// `DigestInfo(SHA-256, H)`: the signer has to do the hashing itself for the
  /// structure to come out right. The value actually covered by the signature
  /// is still the SHA-256 digest, which is what the server verifies against
  /// with `Prehashed`. Returns base64.
  Future<String> signDocument(Uint8List bytes);

  /// Drop the pair, e.g. when signing out of an account for good.
  Future<void> reset();

  /// Where the private key lives, for display in settings.
  String get backendLabel;

  /// SHA-256 of [bytes], as the lowercase hex the server compares against.
  ///
  /// Identical for every backend, so it is implemented once here.
  String digestOf(Uint8List bytes) => crypto.sha256.convert(bytes).toString();
}

/// Picks the strongest backend this device can offer.
///
/// The Keystore is preferred because its key material cannot be read back by
/// any code, this app included. Where the platform channel is missing — a
/// simulator, a unit test, a non-Android target — the pure-Dart backend takes
/// over so signing still works.
Future<SigningService> resolveSigningService({KeyStorage? storage}) async {
  const keystore = KeystoreSigningService();

  if (await keystore.isAvailable()) {
    return keystore;
  }

  return LocalSigningService(storage: storage);
}
