import 'package:flutter_test/flutter_test.dart';

import 'package:passkey_app/data/document_repository.dart';
import 'package:passkey_app/models/document.dart';
import 'package:passkey_app/models/verification.dart';

void main() {
  const repository = MockDocumentRepository();

  group('MockDocumentRepository', () {
    test('covers every status so each badge style is exercised', () async {
      final documents = await repository.fetchDocuments();
      final statuses = documents.map((d) => d.status).toSet();

      expect(statuses, DocumentStatus.values.toSet());
    });

    test('every document has signers and an audit trail', () async {
      final documents = await repository.fetchDocuments();

      for (final document in documents) {
        expect(document.signers, isNotEmpty, reason: document.title);
        expect(document.auditTrail, isNotEmpty, reason: document.title);

        expect(
          document.signers.where((s) => s.isCurrentUser),
          hasLength(1),
          reason: '${document.title} needs exactly one "you" signer',
        );
      }
    });

    test('audit trails are ordered newest first', () async {
      final documents = await repository.fetchDocuments();

      for (final document in documents) {
        final timestamps =
            document.auditTrail.map((e) => e.timestamp).toList();
        final sorted = [...timestamps]..sort((a, b) => b.compareTo(a));

        expect(timestamps, sorted, reason: document.title);
      }
    });

    test('a signed document never also offers to be signed', () async {
      final documents = await repository.fetchDocuments();

      for (final document in documents) {
        expect(
          document.hasSigned && document.canSign,
          isFalse,
          reason: document.title,
        );
      }
    });

    test('fetchDocument resolves by id and returns null otherwise', () async {
      final documents = await repository.fetchDocuments();
      final first = documents.first;

      expect((await repository.fetchDocument(first.id))?.title, first.title);
      expect(await repository.fetchDocument('does-not-exist'), isNull);
    });

    test('verification reports a valid verdict only for a signed document',
        () async {
      final documents = await repository.fetchDocuments();

      final signed = documents.firstWhere(
        (d) => d.status == DocumentStatus.fullySigned,
      );
      final pending = documents.firstWhere(
        (d) => d.status == DocumentStatus.pending,
      );

      expect(
        (await repository.fetchVerification(signed.id)).verdict,
        VerificationVerdict.valid,
      );
      expect(
        (await repository.fetchVerification(pending.id)).verdict,
        VerificationVerdict.incomplete,
      );
    });

    test('signing is not faked: it needs a real server', () async {
      expect(
        () => repository.requestSignChallenge('1', 'a' * 64),
        throwsUnsupportedError,
      );
    });
  });

  group('Document', () {
    test('signature progress tracks the signed signers', () async {
      final documents = await repository.fetchDocuments();

      final signed = documents.firstWhere(
        (d) => d.status == DocumentStatus.fullySigned,
      );

      expect(signed.signedCount, signed.signers.length);
      expect(signed.signatureProgress, 1.0);

      final pending = documents.firstWhere(
        (d) => d.status == DocumentStatus.pending,
      );

      expect(pending.signedCount, 0);
      expect(pending.signatureProgress, 0.0);
    });

    test('a partially signed document sits between the two', () async {
      final documents = await repository.fetchDocuments();

      final partial = documents.firstWhere(
        (d) => d.status == DocumentStatus.partiallySigned,
      );

      expect(partial.signatureProgress, greaterThan(0));
      expect(partial.signatureProgress, lessThan(1));
    });

    test('shortHash abbreviates the digest the way the mockups show', () async {
      final documents = await repository.fetchDocuments();
      final document = documents.first;

      expect(document.fileHash, hasLength(64));
      expect(document.shortHash, 'e3b0c44...b855');
    });
  });
}
