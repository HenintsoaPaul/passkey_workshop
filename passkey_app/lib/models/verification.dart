import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Overall answer to "is this document and its signatures valid?".
///
/// `incomplete` is deliberately not `invalid`: a document nobody has signed
/// yet is not broken, and telling the two apart is the difference between
/// "waiting" and "something is wrong".
enum VerificationVerdict {
  valid('valid', 'Document valide', Icons.verified, AppColors.statusSigned),
  incomplete('incomplete', 'Signatures incomplètes', Icons.hourglass_top,
      AppColors.statusWaiting),
  invalid('invalid', 'Document invalide', Icons.gpp_bad, AppColors.error);

  const VerificationVerdict(this.wireValue, this.label, this.icon, this.color);

  final String wireValue;
  final String label;
  final IconData icon;
  final Color color;

  static VerificationVerdict fromWire(String? value) {
    for (final verdict in values) {
      if (verdict.wireValue == value) {
        return verdict;
      }
    }

    return VerificationVerdict.incomplete;
  }
}

/// One of the four conditions of §2.5.
class VerificationCheck {
  const VerificationCheck({
    required this.code,
    required this.label,
    required this.passed,
    this.detail,
  });

  factory VerificationCheck.fromJson(Map<String, dynamic> json) {
    return VerificationCheck(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      passed: json['passed'] as bool? ?? false,
      detail: json['detail'] as String?,
    );
  }

  final String code;
  final String label;
  final bool passed;

  /// Why it failed, when it did.
  final String? detail;
}

/// One signature and whether it verifies against its signer's public key.
class SignatureReport {
  const SignatureReport({
    required this.signer,
    required this.signerName,
    required this.isValid,
    this.signedAt,
    this.algorithm,
    this.documentHash,
    this.keyFingerprint,
    this.reason,
  });

  factory SignatureReport.fromJson(Map<String, dynamic> json) {
    return SignatureReport(
      signer: json['signer'] as String? ?? '',
      signerName: json['signerName'] as String? ?? '',
      isValid: json['isValid'] as bool? ?? false,
      signedAt: _parseDate(json['signedAt']),
      algorithm: json['algorithm'] as String?,
      documentHash: json['documentHash'] as String?,
      keyFingerprint: json['keyFingerprint'] as String?,
      reason: json['reason'] as String?,
    );
  }

  final String signer;
  final String signerName;
  final bool isValid;
  final DateTime? signedAt;
  final String? algorithm;
  final String? documentHash;
  final String? keyFingerprint;
  final String? reason;
}

/// The server's full verification of a document.
class VerificationReport {
  const VerificationReport({
    required this.documentId,
    required this.verdict,
    required this.signedCount,
    required this.requiredCount,
    required this.checks,
    required this.signatures,
    required this.missingSigners,
    this.currentHash,
    this.storedHash,
    this.versionNumber = 1,
    this.versionCount = 1,
  });

  factory VerificationReport.fromJson(Map<String, dynamic> json) {
    return VerificationReport(
      documentId: json['documentId'].toString(),
      verdict: VerificationVerdict.fromWire(json['verdict'] as String?),
      signedCount: json['signedCount'] as int? ?? 0,
      requiredCount: json['requiredCount'] as int? ?? 0,
      currentHash: json['currentHash'] as String?,
      storedHash: json['storedHash'] as String?,
      versionNumber: json['versionNumber'] as int? ?? 1,
      versionCount: json['versionCount'] as int? ?? 1,
      missingSigners: [
        for (final name in (json['missingSigners'] as List<dynamic>? ?? []))
          name as String,
      ],
      checks: [
        for (final check in (json['checks'] as List<dynamic>? ?? []))
          VerificationCheck.fromJson(check as Map<String, dynamic>),
      ],
      signatures: [
        for (final signature in (json['signatures'] as List<dynamic>? ?? []))
          SignatureReport.fromJson(signature as Map<String, dynamic>),
      ],
    );
  }

  final String documentId;
  final VerificationVerdict verdict;
  final int signedCount;
  final int requiredCount;
  final String? currentHash;
  final String? storedHash;

  /// The revision these checks were run against.
  final int versionNumber;
  final int versionCount;
  final List<String> missingSigners;
  final List<VerificationCheck> checks;
  final List<SignatureReport> signatures;

  bool get isValid => verdict == VerificationVerdict.valid;

  /// The document's digest as it stands now, abbreviated for display.
  String get shortHash {
    final hash = currentHash ?? storedHash ?? '';

    if (hash.length <= 12) {
      return hash;
    }

    return '${hash.substring(0, 7)}...${hash.substring(hash.length - 4)}';
  }

  /// One sentence explaining the verdict, built from the failing checks.
  String get summary {
    switch (verdict) {
      case VerificationVerdict.valid:
        return 'Toutes les signatures sont valides et portent sur la version '
            'actuelle du document.';
      case VerificationVerdict.incomplete:
        return missingSigners.isEmpty
            ? "Ce document n'a pas encore été signé."
            : 'En attente de : ${missingSigners.join(', ')}.';
      case VerificationVerdict.invalid:
        final failed = checks.where((check) => !check.passed);

        for (final check in failed) {
          if (check.detail != null && check.detail!.isNotEmpty) {
            return check.detail!;
          }
        }

        return 'Au moins une vérification cryptographique a échoué.';
    }
  }
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}
