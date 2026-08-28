import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkey_app/models/document.dart';
import 'package:passkey_app/models/verification.dart';

/// Payloads copied from what `chiffrement_app.api` serializes, so a change on
/// either side of the wire shows up here.
final Map<String, dynamic> documentJson = {
  'id': '7',
  'title': 'Contrat multi-signataires',
  'description': 'Document de test',
  'status': 'partially_signed',
  'owner': 'Olivier Owner',
  'ownerUsername': 'owner',
  'fileHash':
      '0548abe5173b9c24cd299687cbd3a30ba341dbb87db808b6f3d7305f9f0728af',
  'fileSize': 19,
  'createdAt': '2026-08-28T09:00:00+00:00',
  'updatedAt': '2026-08-28T10:30:00+00:00',
  'dueDate': null,
  'folderPath': '/ documents / 2026 / 08 / 28',
  'algorithm': 'SHA-256 with RSA-2048',
  'signerCount': 2,
  'signedCount': 1,
  'isSigner': true,
  'hasSigned': false,
  'canSign': true,
  'signers': [
    {
      'username': 'alice',
      'name': 'Alice Martin',
      'email': 'alice@x.fr',
      'status': 'pending',
      'signedAt': null,
      'isCurrentUser': true,
      'keyFingerprint': null,
    },
    {
      'username': 'bob',
      'name': 'Bob Dupont',
      'email': 'bob@x.fr',
      'status': 'signed',
      'signedAt': '2026-08-28T10:30:00+00:00',
      'isCurrentUser': false,
      'keyFingerprint': 'bb' * 32,
    },
  ],
  'auditTrail': [
    {
      'action': 'signed',
      'title': 'Signé',
      'description': 'Signature RSA de Bob Dupont enregistrée',
      'timestamp': '2026-08-28T10:30:00+00:00',
      'actor': 'Bob Dupont',
    },
  ],
};

final Map<String, dynamic> verificationJson = {
  'documentId': '7',
  'verdict': 'invalid',
  'status': 'fully_signed',
  'currentHash': 'aa' * 32,
  'storedHash': 'bb' * 32,
  'signedCount': 2,
  'requiredCount': 2,
  'missingSigners': <String>[],
  'checks': [
    {
      'code': 'signatures_present',
      'label': 'Toutes les signatures obligatoires sont présentes',
      'passed': true,
      'detail': null,
    },
    {
      'code': 'hash_matches',
      'label': "L'empreinte actuelle correspond à l'empreinte signée",
      'passed': false,
      'detail': 'Le document a été modifié depuis sa signature.',
    },
  ],
  'signatures': [
    {
      'signer': 'alice',
      'signerName': 'Alice Martin',
      'signedAt': '2026-08-28T10:00:00+00:00',
      'algorithm': 'RSASSA-PKCS1-v1_5-SHA256',
      'documentHash': 'bb' * 32,
      'keyFingerprint': 'cc' * 32,
      'isValid': true,
      'reason': null,
    },
  ],
};

void main() {
  group('Document.fromJson', () {
    test('reads the fields the API sends', () {
      final document = Document.fromJson(Map.of(documentJson));

      expect(document.id, '7');
      expect(document.title, 'Contrat multi-signataires');
      expect(document.status, DocumentStatus.partiallySigned);
      expect(document.owner, 'Olivier Owner');
      expect(document.fileSize, 19);
      expect(document.canSign, isTrue);
      expect(document.hasSigned, isFalse);
      expect(document.isSigner, isTrue);
      expect(document.createdAt.toUtc().hour, 9);
    });

    test('maps every backend status onto an enum value', () {
      const wireValues = [
        'draft',
        'pending',
        'partially_signed',
        'fully_signed',
        'archived',
      ];

      for (final value in wireValues) {
        expect(
          DocumentStatus.fromWire(value).wireValue,
          value,
          reason: value,
        );
      }
    });

    test('falls back to draft on an unknown status rather than throwing', () {
      expect(DocumentStatus.fromWire('something_new'), DocumentStatus.draft);
      expect(DocumentStatus.fromWire(null), DocumentStatus.draft);
    });

    test('derives the signed count from the signer states', () {
      final document = Document.fromJson(Map.of(documentJson));

      expect(document.signers, hasLength(2));
      expect(document.signedCount, 1);
      expect(document.signatureProgress, 0.5);
    });

    test('marks the current user and keeps the signature timestamp', () {
      final document = Document.fromJson(Map.of(documentJson));

      final me = document.signers.firstWhere((s) => s.isCurrentUser);
      expect(me.name, 'Alice Martin');
      expect(me.status, SignerStatus.pending);
      expect(me.signedAt, isNull);

      final other = document.signers.firstWhere((s) => !s.isCurrentUser);
      expect(other.status, SignerStatus.signed);
      expect(other.signedAt, isNotNull);
      expect(other.keyFingerprint, isNotNull);
    });

    test('turns a log action into an icon', () {
      final document = Document.fromJson(Map.of(documentJson));

      expect(document.auditTrail.single.icon, Icons.fingerprint);
      expect(AuditEvent.iconForAction('created'), Icons.upload_file);
      expect(AuditEvent.iconForAction('inconnu'), Icons.info_outline);
    });

    test('survives a payload missing its optional collections', () {
      final document = Document.fromJson({'id': 3, 'title': 'Minimal'});

      expect(document.id, '3');
      expect(document.signers, isEmpty);
      expect(document.auditTrail, isEmpty);
      expect(document.signatureProgress, 0);
    });
  });

  group('VerificationReport.fromJson', () {
    test('reads the verdict and each check', () {
      final report = VerificationReport.fromJson(Map.of(verificationJson));

      expect(report.verdict, VerificationVerdict.invalid);
      expect(report.isValid, isFalse);
      expect(report.checks, hasLength(2));
      expect(report.checks.first.passed, isTrue);
      expect(report.checks.last.passed, isFalse);
      expect(report.signatures.single.isValid, isTrue);
    });

    test('explains an invalid verdict with the failing check detail', () {
      final report = VerificationReport.fromJson(Map.of(verificationJson));

      expect(report.summary, 'Le document a été modifié depuis sa signature.');
    });

    test('an incomplete verdict names who is still missing', () {
      final report = VerificationReport.fromJson({
        'documentId': '1',
        'verdict': 'incomplete',
        'signedCount': 1,
        'requiredCount': 2,
        'missingSigners': ['Bob Dupont'],
        'checks': [],
        'signatures': [],
      });

      expect(report.summary, contains('Bob Dupont'));
      expect(report.verdict, VerificationVerdict.incomplete);
    });

    test('shows the current hash, not the stored one, when they differ', () {
      final report = VerificationReport.fromJson(Map.of(verificationJson));

      expect(report.shortHash, startsWith('aaaaaaa'));
    });
  });
}
