import 'package:flutter/material.dart';

import '../models/document.dart';

/// Source of the documents shown across the app.
///
/// Every method is asynchronous so the current in-memory implementation can be
/// swapped for an HTTP-backed one without touching any caller.
abstract class DocumentRepository {
  Future<List<Document>> fetchDocuments();

  Future<Document?> fetchDocument(String id);
}

/// Placeholder data used until the Django backend exposes a documents JSON
/// API. Today `chiffrement_app` only serves the four passkey endpoints as
/// JSON; documents, signers and audit logs are reachable through
/// server-rendered HTML views only.
///
/// The mockups disagree with each other about the dataset — the dashboard
/// shows "3 documents / 1 en attente" over two named contracts, while the
/// document list shows three unrelated files. This set reproduces the
/// dashboard counters exactly and still exercises all three badge states.
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
      status: DocumentStatus.signed,
      owner: 'Jean Dupont',
      fileHash:
          '7f4b1d2e6a9c0b3f8e5d4c7a2b1908f6e3d5c4b7a29180f6e3d5c4b7a29a2c11',
      createdAt: DateTime(2023, 10, 20, 8, 30),
      updatedAt: DateTime(2023, 10, 22, 16, 45),
      folderPath: '/ Contrats / 2023 / Q4',
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
  ];
}
