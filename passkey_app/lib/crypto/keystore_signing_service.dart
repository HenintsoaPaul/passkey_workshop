import 'dart:convert';

import 'package:flutter/services.dart';

import 'signing_service.dart';

/// Signing backed by the Android Keystore.
///
/// The key pair is created by the platform, and the private half is never
/// exportable — not to this app either. Every call is a hop over
/// [MethodChannel] to `SigningKeyHandler.kt`.
class KeystoreSigningService extends SigningService {
  const KeystoreSigningService({
    this.channel = const MethodChannel(channelName),
  });

  static const channelName = 'passkey_app/signing_key';

  /// Injectable so the flow can be driven from a test without a device.
  final MethodChannel channel;

  @override
  String get backendLabel => 'Keystore Android (matériel)';

  /// Whether the platform side is present and answering.
  ///
  /// False on any host without the handler — a unit test, iOS, desktop — so
  /// the caller can fall back instead of failing.
  Future<bool> isAvailable() async {
    try {
      return await channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> hasKeyPair() async =>
      await channel.invokeMethod<bool>('hasKeyPair') ?? false;

  @override
  Future<String> ensurePublicKeyPem() async {
    final existing = await channel.invokeMethod<String>('publicKeyPem');

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = await channel.invokeMethod<String>('generate');

    if (generated == null || generated.isEmpty) {
      throw StateError(
        "Le Keystore n'a pas renvoyé de clé publique.",
      );
    }

    return generated;
  }

  @override
  Future<String> signDocument(Uint8List bytes) async {
    final signature = await channel.invokeMethod<Uint8List>(
      'sign',
      <String, Object>{'bytes': bytes},
    );

    if (signature == null) {
      throw StateError('Le Keystore n\'a pas renvoyé de signature.');
    }

    return base64.encode(signature);
  }

  @override
  Future<void> reset() => channel.invokeMethod<void>('delete');
}
