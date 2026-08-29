import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:passkey_app/crypto/key_storage.dart';
import 'package:passkey_app/crypto/local_signing_service.dart';

import 'fixtures/rsa_fixture.dart';

void main() {
  late InMemoryKeyStorage storage;
  late LocalSigningService service;

  setUp(() {
    storage = InMemoryKeyStorage();
    service = LocalSigningService(storage: storage);
  });

  /// Skips key generation, which is seconds of arithmetic, by planting a
  /// known pair. The generation path has its own test below.
  Future<void> plantFixtureKey() async {
    await storage.write(LocalSigningService.privateKeyEntry, testPrivateKeyPem);
    await storage.write(LocalSigningService.publicKeyEntry, testPublicKeyPem);
  }

  group('digestOf', () {
    test('matches the SHA-256 the server computes for the same bytes', () {
      final bytes = Uint8List.fromList(utf8.encode(testMessage));

      expect(service.digestOf(bytes), testDigestHex);
    });

    test('changes when a single byte changes', () {
      final original = Uint8List.fromList(utf8.encode(testMessage));
      final altered = Uint8List.fromList(utf8.encode('$testMessage '));

      expect(service.digestOf(original), isNot(service.digestOf(altered)));
    });
  });

  group('signDocument', () {
    test('produces exactly the signature the Python stack verifies', () async {
      await plantFixtureKey();

      final bytes = Uint8List.fromList(utf8.encode(testMessage));

      // PKCS#1 v1.5 is deterministic, so this is a byte-for-byte comparison
      // against a signature the server's `cryptography` accepts.
      expect(await service.signDocument(bytes), testSignatureBase64);
    });

    test('signs different documents differently', () async {
      await plantFixtureKey();

      final first = await service.signDocument(
        Uint8List.fromList(utf8.encode(testMessage)),
      );
      final second = await service.signDocument(
        Uint8List.fromList(utf8.encode('Un autre contrat.')),
      );

      expect(first, isNot(second));
    });

    test('refuses to sign when the device has no key', () async {
      await expectLater(
        service.signDocument(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('key material', () {
    test('reports whether a pair exists', () async {
      expect(await service.hasKeyPair(), isFalse);

      await plantFixtureKey();

      expect(await service.hasKeyPair(), isTrue);
    });

    test('returns the stored public PEM without regenerating', () async {
      await plantFixtureKey();

      expect(await service.ensurePublicKeyPem(), testPublicKeyPem);
      expect(
        await storage.read(LocalSigningService.privateKeyEntry),
        testPrivateKeyPem,
      );
    });

    test('never exposes the private half through the public PEM', () async {
      await plantFixtureKey();

      expect(await service.ensurePublicKeyPem(), isNot(contains('PRIVATE')));
    });

    test('reset clears both halves', () async {
      await plantFixtureKey();
      await service.reset();

      expect(await service.hasKeyPair(), isFalse);
      expect(await storage.read(LocalSigningService.publicKeyEntry), isNull);
    });
  });

  group('generateKeyPairPems', () {
    test('emits a private PEM the service can read back and sign with',
        () async {
      // The generator and the loader must agree on the PEM shape. They did
      // not at first: basic_utils writes PKCS#8 and its parser rejects the
      // PKCS#1 form, which only surfaced when a signature was attempted.
      final pair = generateKeyPairPems(LocalSigningService.keySize);

      await storage.write(LocalSigningService.privateKeyEntry, pair.privatePem);
      await storage.write(LocalSigningService.publicKeyEntry, pair.publicPem);

      final signature = await service.signDocument(
        Uint8List.fromList(utf8.encode(testMessage)),
      );

      expect(base64.decode(signature), hasLength(256));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('produces a usable, distinct pair', () {
      final pair = generateKeyPairPems(LocalSigningService.keySize);

      expect(pair.privatePem, contains('PRIVATE KEY'));
      expect(pair.publicPem, contains('PUBLIC KEY'));
      expect(pair.publicPem, isNot(contains('PRIVATE')));

      // Two runs must not collide, or every device would share a key.
      final other = generateKeyPairPems(LocalSigningService.keySize);
      expect(pair.privatePem, isNot(other.privatePem));
    },
        // Two RSA-2048 generations in pure Dart; slow but worth running.
        timeout: const Timeout(Duration(minutes: 3)));
  });
}
