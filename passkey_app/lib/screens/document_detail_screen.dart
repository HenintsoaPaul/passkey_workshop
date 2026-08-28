import 'package:flutter/material.dart';

import '../models/document.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/placeholders.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/meta_row.dart';
import '../widgets/passkey_button.dart';
import '../widgets/signature_progress.dart';
import '../widgets/status_badge.dart';

/// Full view of a document: metadata, signature progress, and signers, with
/// the signing action pinned to the bottom.
class DocumentDetailScreen extends StatelessWidget {
  const DocumentDetailScreen({super.key, required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar.withBack(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin,
          AppSpacing.lg,
          AppSpacing.pageMargin,
          AppSpacing.lg,
        ),
        children: [
          _Breadcrumb(path: document.folderPath),

          const SizedBox(height: AppSpacing.sm),

          Text(document.title, style: AppTypography.headlineLg),

          const SizedBox(height: AppSpacing.md),

          MetaRow(label: 'Propriétaire', value: document.owner),

          const SizedBox(height: AppSpacing.xs),

          MetaRow(
            label: 'SHA-256',
            value: document.shortHash,
            tooltip: document.fileHash,
          ),

          const SizedBox(height: AppSpacing.lg),

          SignatureProgress(
            signedCount: document.signedCount,
            totalCount: document.signers.length,
          ),

          const SizedBox(height: AppSpacing.lg),

          const Text('Signataires', style: AppTypography.headlineSm),

          const SizedBox(height: AppSpacing.md),

          for (final signer in document.signers) ...[
            _SignerRow(signer: signer),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
      bottomNavigationBar: _SignActionBar(document: document),
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
                  signer.email,
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

/// Pinned action bar. Signing is not wired up yet: the backend has no JSON
/// endpoint for it, so the button reports that it is still to come.
class _SignActionBar extends StatelessWidget {
  const _SignActionBar({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final alreadySigned = document.signers
        .where((s) => s.isCurrentUser)
        .every((s) => s.status == SignerStatus.signed);

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
          // TODO(api): signing has no JSON endpoint yet in chiffrement_app.
          child: alreadySigned
              ? PasskeyButton.outlined(
                  label: 'Télécharger le document signé',
                  icon: Icons.download,
                  onPressed: () =>
                      showComingSoon(context, 'Téléchargement'),
                )
              : PasskeyButton(
                  label: 'Signer le document',
                  icon: Icons.fingerprint,
                  onPressed: () => showComingSoon(context, 'Signature'),
                ),
        ),
      ),
    );
  }
}
