import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Signature state of a document.
///
/// Mirrors the subset of `Document.STATUS_CHOICES` in the Django backend that
/// the mobile screens display.
enum DocumentStatus {
  draft('BROUILLON', 'Brouillon', AppColors.statusDraft),
  pending('À SIGNER', 'En attente', AppColors.statusWaiting),
  signed('SIGNÉ', 'Signé', AppColors.statusSigned);

  const DocumentStatus(this.badgeLabel, this.label, this.color);

  /// Short uppercase text shown inside a status badge.
  final String badgeLabel;

  /// Sentence-case text used in prose.
  final String label;

  final Color color;
}

/// Where a single signer stands on a document.
enum SignerStatus {
  pending('En attente', Icons.pending, AppColors.statusWaiting),
  signed('Signé', Icons.check_circle, AppColors.statusSigned),
  rejected('Rejeté', Icons.cancel, AppColors.error);

  const SignerStatus(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// A person expected to sign a document.
///
/// Field names follow `DocumentSigner` and `UserProfile` in the backend.
class Signer {
  const Signer({
    required this.name,
    required this.email,
    required this.status,
    this.isCurrentUser = false,
  });

  final String name;
  final String email;
  final SignerStatus status;

  /// Drives the "Vous (…)" prefix and the full-opacity treatment in the
  /// signer list.
  final bool isCurrentUser;
}

/// One entry of a document's audit trail, matching `SignatureLog`.
class AuditEvent {
  const AuditEvent({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.actor,
    required this.icon,
  });

  final String title;
  final String description;
  final DateTime timestamp;
  final String actor;
  final IconData icon;
}

/// A document to be signed.
///
/// Field names mirror `chiffrement_app.models.Document` so a future JSON
/// serializer maps onto this class one-to-one.
class Document {
  const Document({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.owner,
    required this.fileHash,
    required this.createdAt,
    required this.updatedAt,
    required this.folderPath,
    required this.signers,
    required this.auditTrail,
    this.algorithm = 'SHA-256 with RSA-2048',
    this.location = '48.8566° N, 2.3522° E (Paris, FR)',
  });

  final String id;
  final String title;
  final String description;
  final DocumentStatus status;
  final String owner;
  final String fileHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Breadcrumb shown above the title on the detail screen.
  final String folderPath;

  final List<Signer> signers;
  final List<AuditEvent> auditTrail;
  final String algorithm;
  final String location;

  int get signedCount =>
      signers.where((s) => s.status == SignerStatus.signed).length;

  /// 0.0 – 1.0, for the signature progress bar.
  double get signatureProgress =>
      signers.isEmpty ? 0 : signedCount / signers.length;

  /// The abbreviated form the mockups show, e.g. `e3b0c44...b855`.
  String get shortHash {
    if (fileHash.length <= 12) {
      return fileHash;
    }

    return '${fileHash.substring(0, 7)}...'
        '${fileHash.substring(fileHash.length - 4)}';
  }
}
