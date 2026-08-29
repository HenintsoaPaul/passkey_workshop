import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models/document.dart';
import '../models/verification.dart';

/// What the server returns once a signature has been accepted.
class SignatureOutcome {
  const SignatureOutcome({
    required this.document,
    required this.verification,
    required this.keyFingerprint,
  });

  final Document document;
  final VerificationReport verification;
  final String? keyFingerprint;
}

/// Everything the app asks the server about documents.
///
/// The signing calls live here too, so the flow that orchestrates them can be
/// tested against a stub without touching HTTP.
abstract class DocumentRepository {
  Future<List<Document>> fetchDocuments();

  Future<Document?> fetchDocument(String id);

  /// The exact bytes to hash and sign.
  Future<Uint8List> downloadDocument(String id);

  Future<VerificationReport> fetchVerification(String id);

  /// Uploads the public half of the device key pair.
  Future<String?> registerSigningKey(String publicKeyPem);

  /// Asks for the one-shot passkey challenge authorizing one signature.
  Future<Map<String, dynamic>> requestSignChallenge(
    String id,
    String documentHash,
  );

  Future<SignatureOutcome> submitSignature(
    String id, {
    required int challengeId,
    required Map<String, dynamic> credential,
    required String signature,
  });
}

/// The real thing, talking to `/api/` on the Django server.
class HttpDocumentRepository implements DocumentRepository {
  const HttpDocumentRepository();

  @override
  Future<List<Document>> fetchDocuments() async {
    final documents = await Api.fetchDocuments();

    return [
      for (final document in documents)
        Document.fromJson(document as Map<String, dynamic>),
    ];
  }

  @override
  Future<Document?> fetchDocument(String id) async {
    try {
      return Document.fromJson(await Api.fetchDocument(id));
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }

      rethrow;
    }
  }

  @override
  Future<Uint8List> downloadDocument(String id) => Api.downloadDocument(id);

  @override
  Future<VerificationReport> fetchVerification(String id) async {
    return VerificationReport.fromJson(await Api.fetchVerification(id));
  }

  @override
  Future<String?> registerSigningKey(String publicKeyPem) async {
    final response = await Api.registerSigningKey(publicKeyPem);
    final key = response['signingKey'] as Map<String, dynamic>?;

    return key?['fingerprint'] as String?;
  }

  @override
  Future<Map<String, dynamic>> requestSignChallenge(
    String id,
    String documentHash,
  ) =>
      Api.signChallenge(id, documentHash);

  @override
  Future<SignatureOutcome> submitSignature(
    String id, {
    required int challengeId,
    required Map<String, dynamic> credential,
    required String signature,
  }) async {
    final response = await Api.submitSignature(
      id,
      challengeId: challengeId,
      credential: credential,
      signature: signature,
    );

    return SignatureOutcome(
      document: Document.fromJson(response['document'] as Map<String, dynamic>),
      verification: VerificationReport.fromJson(
        response['verification'] as Map<String, dynamic>,
      ),
      keyFingerprint:
          (response['signature'] as Map<String, dynamic>?)?['keyFingerprint']
              as String?,
    );
  }
}

/// Fixture data for widget tests and for laying out screens without a server.
///
/// Covers every [DocumentStatus] so each badge style is exercised. The signing
/// calls are deliberately unimplemented: a signature needs a real
/// authenticator and a real key, and a fake one here would prove nothing.
class MockDocumentRepository implements DocumentRepository {
  const MockDocumentRepository();

  @override
  Future<List<Document>> fetchDocuments() async => _documents;

  @override
  Future<Document?> fetchDocument(String id) async {
    for (final document in _documents) {
      if (document.id == id) {
        return document;
      }
    }

    return null;
  }

  @override
  Future<Uint8List> downloadDocument(String id) async =>
      Uint8List.fromList('Contenu de démonstration pour $id.'.codeUnits);

  @override
  Future<VerificationReport> fetchVerification(String id) async {
    final document = await fetchDocument(id) ?? _documents.first;
    final signed = document.status == DocumentStatus.fullySigned;

    return VerificationReport(
      documentId: document.id,
      verdict: signed
          ? VerificationVerdict.valid
          : VerificationVerdict.incomplete,
      signedCount: document.signedCount,
      requiredCount: document.signers.length,
      currentHash: document.fileHash,
      storedHash: document.fileHash,
      missingSigners: [
        for (final signer in document.signers)
          if (signer.status != SignerStatus.signed) signer.name,
      ],
      checks: [
        VerificationCheck(
          code: 'signatures_present',
          label: 'Toutes les signatures obligatoires sont présentes',
          passed: signed,
        ),
        VerificationCheck(
          code: 'signatures_valid',
          label: 'Toutes les signatures sont valides',
          passed: signed,
        ),
        const VerificationCheck(
          code: 'same_version',
          label: 'Toutes les signatures portent sur la même version',
          passed: true,
        ),
        VerificationCheck(
          code: 'hash_matches',
          label: "L'empreinte actuelle correspond à l'empreinte signée",
          passed: signed,
        ),
      ],
      signatures: const [],
    );
  }

  @override
  Future<String?> registerSigningKey(String publicKeyPem) async => null;

  @override
  Future<Map<String, dynamic>> requestSignChallenge(
    String id,
    String documentHash,
  ) =>
      throw UnsupportedError('Signature indisponible sans serveur.');

  @override
  Future<SignatureOutcome> submitSignature(
    String id, {
    required int challengeId,
    required Map<String, dynamic> credential,
    required String signature,
  }) =>
      throw UnsupportedError('Signature indisponible sans serveur.');

  static final List<Document> _documents = [
    Document(
      id: 'DOC-88392-XYZ-2023',
      title: 'Contrat de Prestation S.A.',
      description:
          "Accord de partenariat pour la coentreprise du troisième trimestre. "
          "Requiert la signature des deux conseils d'administration.",
      status: DocumentStatus.pending,
      owner: 'Jean Dupont',
      fileHash:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      createdAt: DateTime(2023, 10, 23, 9, 0, 11),
      updatedAt: DateTime(2023, 10, 24, 14, 32, 5),
      folderPath: '/ Contrats / 2023 / Q4',
      isSigner: true,
      canSign: true,
      signers: const [
        Signer(
          name: 'Jean Dupont',
          email: 'jean.dupont@entreprise.com',
          status: SignerStatus.pending,
          isCurrentUser: true,
        ),
        Signer(
          name: 'Marie Martin',
          email: 'marie.martin@partenaire.com',
          status: SignerStatus.pending,
        ),
      ],
      auditTrail: [
        AuditEvent(
          title: 'Document consulté',
          description: 'Lien sécurisé ouvert depuis l\'IP 192.168.1.45',
          timestamp: DateTime.utc(2023, 10, 24, 14, 15, 22),
          actor: 'Jean Dupont',
          icon: Icons.visibility,
        ),
        AuditEvent(
          title: 'Document créé',
          description: 'Téléversé et initialisé pour signature',
          timestamp: DateTime.utc(2023, 10, 23, 9, 0, 11),
          actor: 'Administrateur système',
          icon: Icons.upload_file,
        ),
      ],
    ),
    Document(
      id: 'DOC-77145-NDA-2023',
      title: 'Accord de Confidentialité (NDA)',
      description:
          'Accord de confidentialité et de non-divulgation pour les nouveaux '
          'prestataires rejoignant le site sécurisé.',
      status: DocumentStatus.fullySigned,
      owner: 'Jean Dupont',
      fileHash:
          '7f4b1d2e6a9c0b3f8e5d4c7a2b1908f6e3d5c4b7a29180f6e3d5c4b7a29a2c11',
      createdAt: DateTime(2023, 10, 20, 8, 30),
      updatedAt: DateTime(2023, 10, 22, 16, 45),
      folderPath: '/ Contrats / 2023 / Q4',
      isSigner: true,
      hasSigned: true,
      signers: const [
        Signer(
          name: 'Jean Dupont',
          email: 'jean.dupont@entreprise.com',
          status: SignerStatus.signed,
          isCurrentUser: true,
        ),
        Signer(
          name: 'Éléonore Vance',
          email: 'eleonore.vance@entreprise.com',
          status: SignerStatus.signed,
        ),
      ],
      auditTrail: [
        AuditEvent(
          title: 'Document signé',
          description: 'Authentification biométrique par passkey réussie',
          timestamp: DateTime.utc(2023, 10, 22, 16, 45, 3),
          actor: 'Éléonore Vance (PDG)',
          icon: Icons.fingerprint,
        ),
        AuditEvent(
          title: 'Document signé',
          description: 'Authentification biométrique par passkey réussie',
          timestamp: DateTime.utc(2023, 10, 21, 11, 12, 40),
          actor: 'Jean Dupont',
          icon: Icons.fingerprint,
        ),
        AuditEvent(
          title: 'Document créé',
          description: 'Téléversé et initialisé pour signature',
          timestamp: DateTime.utc(2023, 10, 20, 8, 30, 0),
          actor: 'Administrateur système',
          icon: Icons.upload_file,
        ),
      ],
    ),
    Document(
      id: 'DOC-65098-LIC-2023',
      title: 'Licence Logicielle Entreprise',
      description:
          'Première version du contrat de licence logicielle pour le '
          'déploiement en entreprise.',
      status: DocumentStatus.draft,
      owner: 'Jean Dupont',
      fileHash:
          '9a2c5f1b8e4d7c0a3f6b9e2d5c8a1f4b7e0d3c6a9f2b5e8d1c4a7f0b3e6d9c2a',
      createdAt: DateTime(2023, 10, 18, 15, 5),
      updatedAt: DateTime(2023, 10, 18, 15, 5),
      folderPath: '/ Contrats / 2023 / Q4',
      signers: const [
        Signer(
          name: 'Jean Dupont',
          email: 'jean.dupont@entreprise.com',
          status: SignerStatus.pending,
          isCurrentUser: true,
        ),
      ],
      auditTrail: [
        AuditEvent(
          title: 'Document créé',
          description: 'Brouillon enregistré, signataires non assignés',
          timestamp: DateTime.utc(2023, 10, 18, 15, 5, 0),
          actor: 'Jean Dupont',
          icon: Icons.upload_file,
        ),
      ],
    ),
    Document(
      id: 'DOC-51204-BAI-2023',
      title: 'Bail Commercial Rue Lafayette',
      description:
          'Bail commercial signé par le bailleur, en attente de la signature '
          'du preneur.',
      status: DocumentStatus.partiallySigned,
      owner: 'Sophie Bernard',
      fileHash:
          '4d8f2a7c1e9b6d3f0a5c8e2b7d4f1a9c6e3b0d7f4a1c8e5b2d9f6a3c0e7b4d1f',
      createdAt: DateTime(2023, 10, 15, 10, 20),
      updatedAt: DateTime(2023, 10, 17, 9, 5),
      folderPath: '/ Baux / 2023',
      isSigner: true,
      canSign: true,
      signers: const [
        Signer(
          name: 'Jean Dupont',
          email: 'jean.dupont@entreprise.com',
          status: SignerStatus.viewed,
          isCurrentUser: true,
        ),
        Signer(
          name: 'Sophie Bernard',
          email: 'sophie.bernard@bailleur.fr',
          status: SignerStatus.signed,
        ),
      ],
      auditTrail: [
        AuditEvent(
          title: 'Document signé',
          description: 'Authentification biométrique par passkey réussie',
          timestamp: DateTime.utc(2023, 10, 17, 9, 5, 12),
          actor: 'Sophie Bernard',
          icon: Icons.fingerprint,
        ),
        AuditEvent(
          title: 'Document créé',
          description: 'Téléversé et initialisé pour signature',
          timestamp: DateTime.utc(2023, 10, 15, 10, 20, 0),
          actor: 'Sophie Bernard',
          icon: Icons.upload_file,
        ),
      ],
    ),
    Document(
      id: 'DOC-40311-ARC-2022',
      title: 'Convention de Stage 2022',
      description:
          'Convention archivée après signature complète, conservée pour '
          'référence.',
      status: DocumentStatus.archived,
      owner: 'Jean Dupont',
      fileHash:
          '1b7e4a0c9d6f3b8e5a2c7f0d4b1e8a5c2f9d6b3e0a7c4f1b8e5d2a9c6f3b0e7d',
      createdAt: DateTime(2022, 9, 1, 8, 0),
      updatedAt: DateTime(2022, 9, 30, 17, 45),
      folderPath: '/ Archives / 2022',
      isSigner: true,
      hasSigned: true,
      signers: const [
        Signer(
          name: 'Jean Dupont',
          email: 'jean.dupont@entreprise.com',
          status: SignerStatus.signed,
          isCurrentUser: true,
        ),
      ],
      auditTrail: [
        AuditEvent(
          title: 'Document signé',
          description: 'Authentification biométrique par passkey réussie',
          timestamp: DateTime.utc(2022, 9, 30, 17, 45, 0),
          actor: 'Jean Dupont',
          icon: Icons.fingerprint,
        ),
      ],
    ),
  ];
}
