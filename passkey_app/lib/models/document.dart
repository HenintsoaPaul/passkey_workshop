import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Signature state of a document.
///
/// Mirrors `Document.STATUS_CHOICES` in the Django backend, including the
/// three states §1 of the TP names: waiting, partially signed, fully signed.
enum DocumentStatus {
  draft('draft', 'BROUILLON', 'Brouillon', AppColors.statusDraft),
  pending('pending', 'À SIGNER', 'En attente de signature',
      AppColors.statusWaiting),
  partiallySigned('partially_signed', 'PARTIEL', 'Partiellement signé',
      AppColors.statusPartial),
  fullySigned('fully_signed', 'SIGNÉ', 'Complètement signé',
      AppColors.statusSigned),
  archived('archived', 'ARCHIVÉ', 'Archivé', AppColors.statusDraft);

  const DocumentStatus(
    this.wireValue,
    this.badgeLabel,
    this.label,
    this.color,
  );

  /// The string the API uses.
  final String wireValue;

  /// Short uppercase text shown inside a status badge.
  final String badgeLabel;

  /// Sentence-case text used in prose.
  final String label;

  final Color color;

  static DocumentStatus fromWire(String? value) {
    for (final status in values) {
      if (status.wireValue == value) {
        return status;
      }
    }

    return DocumentStatus.draft;
  }
}

/// Where a single signer stands on a document.
enum SignerStatus {
  pending('pending', 'En attente', Icons.pending, AppColors.statusWaiting),
  viewed('viewed', 'Consulté', Icons.visibility, AppColors.statusWaiting),
  accepted('accepted', 'Accepté', Icons.thumb_up, AppColors.statusPartial),
  signed('signed', 'Signé', Icons.check_circle, AppColors.statusSigned),
  rejected('rejected', 'Rejeté', Icons.cancel, AppColors.error);

  const SignerStatus(this.wireValue, this.label, this.icon, this.color);

  final String wireValue;
  final String label;
  final IconData icon;
  final Color color;

  static SignerStatus fromWire(String? value) {
    for (final status in values) {
      if (status.wireValue == value) {
        return status;
      }
    }

    return SignerStatus.pending;
  }
}

/// A person expected to sign a document.
class Signer {
  const Signer({
    required this.name,
    required this.email,
    required this.status,
    this.isCurrentUser = false,
    this.signedAt,
    this.keyFingerprint,
  });

  factory Signer.fromJson(Map<String, dynamic> json) {
    return Signer(
      name: json['name'] as String? ?? json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: SignerStatus.fromWire(json['status'] as String?),
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
      signedAt: _parseDate(json['signedAt']),
      keyFingerprint: json['keyFingerprint'] as String?,
    );
  }

  final String name;
  final String email;
  final SignerStatus status;

  /// Drives the "Vous (…)" prefix and the full-opacity treatment in the
  /// signer list.
  final bool isCurrentUser;

  final DateTime? signedAt;

  /// Which RSA key produced this signer's signature, when they have signed.
  final String? keyFingerprint;
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

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestamp: _parseDate(json['timestamp']) ?? DateTime.now(),
      actor: json['actor'] as String? ?? '',
      icon: iconForAction(json['action'] as String?),
    );
  }

  /// The backend logs an action name, not an icon; the mapping belongs here
  /// rather than in every widget that renders a trail.
  static IconData iconForAction(String? action) {
    switch (action) {
      case 'signed':
        return Icons.fingerprint;
      case 'viewed':
        return Icons.visibility;
      case 'created':
        return Icons.upload_file;
      case 'version_added':
        return Icons.difference;
      case 'assigned':
        return Icons.person_add;
      case 'unassigned':
        return Icons.person_remove;
      case 'archived':
        return Icons.inventory_2;
      case 'accepted':
        return Icons.thumb_up;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  final String title;
  final String description;
  final DateTime timestamp;
  final String actor;
  final IconData icon;
}

/// A document to be signed.
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
    this.fileSize,
    this.versionNumber = 1,
    this.versionCount = 1,
    this.canSign = false,
    this.hasSigned = false,
    this.isSigner = false,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    return Document(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: DocumentStatus.fromWire(json['status'] as String?),
      owner: json['owner'] as String? ?? '',
      fileHash: json['fileHash'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']) ?? now,
      updatedAt: _parseDate(json['updatedAt']) ?? now,
      folderPath: json['folderPath'] as String? ?? '/',
      algorithm: json['algorithm'] as String? ?? 'SHA-256 with RSA-2048',
      fileSize: json['fileSize'] as int?,
      versionNumber: json['versionNumber'] as int? ?? 1,
      versionCount: json['versionCount'] as int? ?? 1,
      canSign: json['canSign'] as bool? ?? false,
      hasSigned: json['hasSigned'] as bool? ?? false,
      isSigner: json['isSigner'] as bool? ?? false,
      signers: [
        for (final signer in (json['signers'] as List<dynamic>? ?? []))
          Signer.fromJson(signer as Map<String, dynamic>),
      ],
      auditTrail: [
        for (final event in (json['auditTrail'] as List<dynamic>? ?? []))
          AuditEvent.fromJson(event as Map<String, dynamic>),
      ],
    );
  }

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
  final int? fileSize;

  /// Which revision of the content this is. A new version invalidates every
  /// signature made against the previous one (§2.5).
  final int versionNumber;

  /// How many revisions exist in total.
  final int versionCount;

  /// Whether this document has been revised since it was created.
  bool get hasEarlierVersions => versionCount > 1;

  /// Whether the signed-in user may sign this document right now.
  final bool canSign;

  /// Whether the signed-in user has already signed it.
  final bool hasSigned;

  /// Whether the signed-in user is one of the assigned signers at all.
  final bool isSigner;

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

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}
