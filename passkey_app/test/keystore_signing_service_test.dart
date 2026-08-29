import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkey_app/crypto/keystore_signing_service.dart';

import 'fixtures/rsa_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(KeystoreSigningService.channelName);
  const service = KeystoreSigningService();

  final calls = <MethodCall>[];

  /// Stands in for `SigningKeyHandler.kt`.
  void mockPlatform(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('isAvailable', () {
    test('is false when the platform side is not registered', () async {
      // No mock handler at all: exactly what a host without the Kotlin
      // handler looks like, and the app must fall back rather than crash.
      expect(await service.isAvailable(), isFalse);
    });

    test('is false when the platform side errors', () async {
      mockPlatform((_) => throw PlatformException(code: 'keystore_error'));

      expect(await service.isAvailable(), isFalse);
    });

    test('is true when the handler answers', () async {
      mockPlatform((_) => true);

      expect(await service.isAvailable(), isTrue);
    });
  });

  group('key material', () {
    test('reports an existing pair', () async {
      mockPlatform((call) => call.method == 'hasKeyPair');

      expect(await service.hasKeyPair(), isTrue);
      expect(calls.single.method, 'hasKeyPair');
    });

    test('returns the existing public key without regenerating', () async {
      mockPlatform((call) =>
          call.method == 'publicKeyPem' ? testPublicKeyPem : null);

      expect(await service.ensurePublicKeyPem(), testPublicKeyPem);
      expect(calls.map((c) => c.method), ['publicKeyPem']);
    });

    test('generates only when the Keystore holds nothing yet', () async {
      mockPlatform((call) => switch (call.method) {
            'publicKeyPem' => null,
            'generate' => testPublicKeyPem,
            _ => null,
          });

      expect(await service.ensurePublicKeyPem(), testPublicKeyPem);
      expect(calls.map((c) => c.method), ['publicKeyPem', 'generate']);
    });

    test('never surfaces private key material', () async {
      mockPlatform((call) =>
          call.method == 'publicKeyPem' ? testPublicKeyPem : null);

      expect(await service.ensurePublicKeyPem(), isNot(contains('PRIVATE')));
    });

    test('fails loudly if generation returns nothing usable', () async {
      mockPlatform((call) => call.method == 'generate' ? '' : null);

      await expectLater(
        service.ensurePublicKeyPem(),
        throwsA(isA<StateError>()),
      );
    });

    test('reset asks the platform to delete the key', () async {
      mockPlatform((_) => null);

      await service.reset();

      expect(calls.single.method, 'delete');
    });
  });

  group('signDocument', () {
    test('passes the document bytes through and base64-encodes the result',
        () async {
      final signature = Uint8List.fromList(List<int>.generate(256, (i) => i));

      mockPlatform((call) => call.method == 'sign' ? signature : null);

      final bytes = Uint8List.fromList(utf8.encode(testMessage));
      final encoded = await service.signDocument(bytes);

      expect(encoded, base64.encode(signature));

      // The platform signs the document bytes; SHA256withRSA hashes them on
      // the Kotlin side, which is what makes the digest the signed value.
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['bytes'], bytes);
    });

    test('fails loudly when the platform returns no signature', () async {
      mockPlatform((_) => null);

      await expectLater(
        service.signDocument(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<StateError>()),
      );
    });

    test('lets a platform error surface rather than signing nothing', () async {
      mockPlatform(
        (_) => throw PlatformException(
          code: 'keystore_error',
          message: 'Aucune clé de signature dans le Keystore.',
        ),
      );

      await expectLater(
        service.signDocument(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  test('names the backend for the settings screen', () {
    expect(service.backendLabel, contains('Keystore'));
  });
}
