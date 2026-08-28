import 'package:flutter/material.dart';

import '../data/document_repository.dart';
import '../data/signing_coordinator.dart';
import '../models/document.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/meta_row.dart';
import '../widgets/passkey_button.dart';
import '../widgets/signature_progress.dart';
import '../widgets/status_badge.dart';

/// Full view of a document: metadata, signature progress, and signers, with
/// the signing action pinned to the bottom.
class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({
    super.key,
    required this.document,
    required this.repository,
    required this.coordinator,
    this.onChanged,
  });

  final Document document;
  final DocumentRepository repository;
  final SigningCoordinator coordinator;

  /// Lets the list that opened this screen refresh after a signature.
  final VoidCallback? onChanged;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late Document _document = widget.document;

  SigningStep? _step;
  String? _error;

  bool get _busy => _step != null;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// The card that opened this screen carries a summary; the detail endpoint
  /// adds the audit trail and the per-signer signature state.
  Future<void> _refresh() async {
    try {
      final fresh = await widget.repository.fetchDocument(_document.id);

      if (fresh != null && mounted) {
        setState(() => _document = fresh);
      }
    } catch (_) {
      // A failed refresh leaves the summary on screen, which is still useful;
      // signing surfaces its own errors.
    }
  }

  void _setStep(SigningStep? step) {
    if (mounted) {
      setState(() => _step = step);
    }
  }

  Future<void> _sign() async {
    setState(() => _error = null);

    try {
      final preview = await widget.coordinator.prepare(
        _document,
        onStep: _setStep,
      );

      _setStep(null);

      if (!mounted) {
        return;
      }

      // §2.4 step 1–2: the signer sees the exact digest before confirming.
      final confirmed = await _confirmSignature(preview.documentHash);

      if (confirmed != true) {
        return;
      }

      final outcome = await widget.coordinator.sign(
        _document,
        preview,
        onStep: _setStep,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _document = outcome.document;
        _step = null;
      });

      widget.onChanged?.call();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              outcome.verification.isValid
                  ? 'Document signé. Toutes les signatures sont valides.'
                  : 'Signature enregistrée. '
                      '${outcome.verification.signedCount} sur '
                      '${outcome.verification.requiredCount} signataires.',
            ),
          ),
        );
    } catch (error) {
      _setStep(null);

      if (mounted) {
        setState(() => _error = error.toString());
      }
    }
  }

  Future<bool?> _confirmSignature(String documentHash) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      isScrollControlled: true,
      builder: (context) => _ConfirmSheet(
        document: _document,
        documentHash: documentHash,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar.withBack(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            AppSpacing.lg,
            AppSpacing.pageMargin,
            AppSpacing.lg,
          ),
          children: [
            _Breadcrumb(path: _document.folderPath),

            const SizedBox(height: AppSpacing.sm),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(_document.title, style: AppTypography.headlineLg),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusBadge.document(_document.status),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            MetaRow(label: 'Propriétaire', value: _document.owner),

            const SizedBox(height: AppSpacing.xs),

            MetaRow(
              label: 'SHA-256',
              value: _document.shortHash,
              tooltip: _document.fileHash,
            ),

            const SizedBox(height: AppSpacing.lg),

            SignatureProgress(
              signedCount: _document.signedCount,
              totalCount: _document.signers.length,
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorCard(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            const Text('Signataires', style: AppTypography.headlineSm),

            const SizedBox(height: AppSpacing.md),

            for (final signer in _document.signers) ...[
              _SignerRow(signer: signer),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _SignActionBar(
        document: _document,
        step: _step,
        onSign: _busy ? null : _sign,
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.folder,
          size: 16,
          color: AppColors.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            path,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSm,
          ),
        ),
      ],
    );
  }
}

class _SignerRow extends StatelessWidget {
  const _SignerRow({required this.signer});

  final Signer signer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      opacity: signer.isCurrentUser ? 1 : 0.7,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerHighest,
            ),
            child: const Icon(
              Icons.person,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signer.isCurrentUser
                      ? 'Vous (${signer.name})'
                      : signer.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: signer.isCurrentUser
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                Text(
                  signer.signedAt != null
                      ? 'Signé ${formatRelative(signer.signedAt!)}'
                      : signer.email,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm,
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          StatusBadge.signer(signer.status),
        ],
      ),
    );
  }
}

/// Pinned action bar: the sign button, the progress of an in-flight signature,
/// or a line explaining why signing is not offered.
class _SignActionBar extends StatelessWidget {
  const _SignActionBar({
    required this.document,
    required this.step,
    required this.onSign,
  });

  final Document document;
  final SigningStep? step;
  final VoidCallback? onSign;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.9),
        border: const Border(
          top: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageMargin),
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    if (step != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              step!.label,
              style: AppTypography.button.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    if (document.hasSigned) {
      return const _SignedNotice();
    }

    if (!document.canSign) {
      return Text(
        document.isSigner
            ? 'Ce document n\'attend plus votre signature.'
            : 'Vous n\'êtes pas signataire de ce document.',
        textAlign: TextAlign.center,
        style: AppTypography.labelMd,
      );
    }

    return PasskeyButton(
      label: 'Signer le document',
      icon: Icons.fingerprint,
      onPressed: onSign,
    );
  }
}

class _SignedNotice extends StatelessWidget {
  const _SignedNotice();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle,
          size: 18,
          color: AppColors.statusSigned,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Vous avez signé ce document',
          style: AppTypography.button.copyWith(
            color: AppColors.statusSigned,
          ),
        ),
      ],
    );
  }
}

/// Shows the digest the phone computed, then asks for the passkey.
///
/// §2.1 requires a fresh confirmation for each signature; showing the hash
/// first makes it a confirmation of *this* document rather than a reflex tap.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.document, required this.documentHash});

  final Document document;
  final String documentHash;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Icon(
                Icons.fingerprint,
                size: 40,
                color: AppColors.primary,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            const Text(
              'Confirmer la signature',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSm,
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              'Vous allez signer « ${document.title} » avec la clé privée de '
              'cet appareil. Votre passkey sera demandée pour confirmer.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EMPREINTE CALCULÉE SUR CET APPAREIL',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    documentHash,
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            PasskeyButton(
              label: 'Confirmer avec ma passkey',
              icon: Icons.key,
              onPressed: () => Navigator.of(context).pop(true),
            ),

            const SizedBox(height: AppSpacing.sm),

            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMd.copyWith(color: AppColors.error),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.error,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
