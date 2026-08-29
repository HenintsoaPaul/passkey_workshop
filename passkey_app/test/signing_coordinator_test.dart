import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:passkey_app/crypto/key_storage.dart';
import 'package:passkey_app/crypto/local_signing_service.dart';
import 'package:passkey_app/data/document_repository.dart';
import 'package:passkey_app/data/signing_coordinator.dart';
import 'package:passkey_app/models/document.dart';
import 'package:passkey_app/models/verification.dart';

import 'fixtures/rsa_fixture.dart';

/// Records what the coordinator sends, and returns canned server answers.
class FakeRepository implements DocumentRepository {
  FakeRepository({String? content})
      : bytes = Uint8List.fromList(utf8.encode(content ?? testMessage));

  final Uint8List bytes;

  final List<String> calls = [];

  String? registeredPublicKey;
  String? challengedHash;
  String? submittedSignature;
  int? submittedChallengeId;
  Map<String, dynamic>? submittedCredential;

  Object? challengeError;

  @override
  Future<Uint8List> downloadDocument(String id) async {
    calls.add('download');
    return bytes;
  }

  @override
  Future<String?> registerSigningKey(String publicKeyPem) async {
    calls.add('registerKey');
    registeredPublicKey = publicKeyPem;
    return 'fingerprint-abc';
  }

  @override
  Future<Map<String, dynamic>> requestSignChallenge(
    String id,
    String documentHash,
  ) async {
    calls.add('challenge');
    challengedHash = documentHash;

    if (challengeError != null) {
      throw challengeError!;
    }

    return {
      'challengeId': 42,
      'documentHash': documentHash,
      'publicKeyOptions': {'challenge': 'server-nonce'},
    };
  }

  @override
  Future<SignatureOutcome> submitSignature(
    String id, {
    required int challengeId,
    required Map<String, dynamic> credential,
    required String signature,
  }) async {
    calls.add('submit');
    submittedChallengeId = challengeId;
    submittedCredential = credential;
    submittedSignature = signature;

    return SignatureOutcome(
      document: _document(hasSigned: true),
      verification: const VerificationReport(
        documentId: '1',
        verdict: VerificationVerdict.valid,
        signedCount: 1,
        requiredCount: 1,
        checks: [],
        signatures: [],
        missingSigners: [],
      ),
      keyFingerprint: 'fingerprint-abc',
    );
  }

  @override
  Future<List<Document>> fetchDocuments() async => [_document()];

  @override
  Future<Document?> fetchDocument(String id) async => _document();

  @override
  Future<VerificationReport> fetchVerification(String id) async =>
      const VerificationReport(
        documentId: '1',
        verdict: VerificationVerdict.incomplete,
        signedCount: 0,
        requiredCount: 1,
        checks: [],
        signatures: [],
        missingSigners: [],
      );
}

Document _document({bool hasSigned = false, String? fileHash}) {
  return Document(
    id: '1',
    title: 'Contrat de test',
    description: '',
    status: hasSigned ? DocumentStatus.fullySigned : DocumentStatus.pending,
    owner: 'Olivier',
    fileHash: fileHash ?? testDigestHex,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 2),
    folderPath: '/ documents',
    isSigner: true,
    canSign: !hasSigned,
    hasSigned: hasSigned,
    signers: const [],
    auditTrail: const [],
  );
}

void main() {
  late FakeRepository repository;
  late LocalSigningService signingService;
  late InMemoryKeyStorage storage;
  late List<Map<String, dynamic>> passkeyCalls;

  SigningCoordinator build({
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? authenticator,
  }) {
    return SigningCoordinator(
      repository: repository,
      signingService: signingService,
      confirmWithPasskey: authenticator ??
          (options) async {
            passkeyCalls.add(options);
            return {'rawId': 'credential-1'};
          },
    );
  }

  setUp(() async {
    repository = FakeRepository();
    storage = InMemoryKeyStorage();
    signingService = LocalSigningService(storage: storage);
    passkeyCalls = [];

    await storage.write(LocalSigningService.privateKeyEntry, testPrivateKeyPem);
    await storage.write(LocalSigningService.publicKeyEntry, testPublicKeyPem);
  });

  group('prepare', () {
    test('hashes the bytes it downloaded, not the value the server sent',
        () async {
      final preview = await build().prepare(_document());

      expect(repository.calls, contains('download'));
      expect(preview.documentHash, testDigestHex);
      expect(preview.bytes, repository.bytes);
    });

    test('reports every step in order', () async {
      final steps = <SigningStep>[];

      await build().prepare(_document(), onStep: steps.add);

      expect(steps, [SigningStep.downloading, SigningStep.hashing]);
    });

    test('refuses a document whose bytes disagree with the server hash',
        () async {
      await expectLater(
        build().prepare(_document(fileHash: 'f' * 64)),
        throwsA(isA<DocumentMismatchException>()),
      );
    });
  });

  group('sign', () {
    test('confirms with the passkey before sending the signature', () async {
      final coordinator = build();
      final preview = await coordinator.prepare(_document());

      await coordinator.sign(_document(), preview);

      // The passkey confirmation must be requested, and it must happen before
      // the signature reaches the server.
      expect(passkeyCalls, hasLength(1));
      expect(passkeyCalls.single, {'challenge': 'server-nonce'});
      expect(
        repository.calls.indexOf('challenge'),
        lessThan(repository.calls.indexOf('submit')),
      );
    });

    test('asks for a challenge bound to the locally computed digest',
        () async {
      final coordinator = build();
      final preview = await coordinator.prepare(_document());

      await coordinator.sign(_document(), preview);

      expect(repository.challengedHash, testDigestHex);
      expect(repository.submittedChallengeId, 42);
      expect(repository.submittedCredential, {'rawId': 'credential-1'});
    });

    test('sends the signature the server stack accepts', () async {
      final coordinator = build();
      final preview = await coordinator.prepare(_document());

      await coordinator.sign(_document(), preview);

      expect(repository.submittedSignature, testSignatureBase64);
    });

    test('registers the public key, never the private one', () async {
      final coordinator = build();
      final preview = await coordinator.prepare(_document());

      await coordinator.sign(_document(), preview);

      expect(repository.registeredPublicKey, testPublicKeyPem);
      expect(repository.registeredPublicKey, isNot(contains('PRIVATE')));
    });

    test('a refused passkey stops the signature from being sent', () async {
      final coordinator = build(
        authenticator: (_) async => throw StateError('user cancelled'),
      );

      final preview = await coordinator.prepare(_document());

      await expectLater(
        coordinator.sign(_document(), preview),
        throwsA(isA<StateError>()),
      );

      expect(repository.calls, isNot(contains('submit')));
      expect(repository.submittedSignature, isNull);
    });

    test('a refused challenge stops before the passkey is even shown',
        () async {
      repository.challengeError = Exception('already_signed');

      final coordinator = build();
      final preview = await coordinator.prepare(_document());

      await expectLater(
        coordinator.sign(_document(), preview),
        throwsA(isA<Exception>()),
      );

      expect(passkeyCalls, isEmpty);
      expect(repository.calls, isNot(contains('submit')));
    });

    test('reports the remaining steps in order', () async {
      final coordinator = build();
      final preview = await coordinator.prepare(_document());
      final steps = <SigningStep>[];

      await coordinator.sign(_document(), preview, onStep: steps.add);

      expect(steps, [
        SigningStep.requestingChallenge,
        SigningStep.confirming,
        SigningStep.signing,
        SigningStep.submitting,
      ]);
    });
  });

  group('ensureKeyRegistered', () {
    test('uploads the public PEM and returns the server fingerprint',
        () async {
      expect(await build().ensureKeyRegistered(), 'fingerprint-abc');
      expect(repository.registeredPublicKey, testPublicKeyPem);
    });
  });
}
