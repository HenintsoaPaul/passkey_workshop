import 'package:flutter/material.dart';

import '../data/document_repository.dart';
import '../models/document.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/placeholders.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/audit_timeline.dart';
import '../widgets/passkey_button.dart';

/// Audit trail and cryptographic verification for a signed document.
///
/// Only the mobile layout of the mockup is implemented; its `md:` breakpoint
/// side navigation is a desktop-web concern and does not apply here.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({
    super.key,
    required this.repository,
    required this.onBackToDocuments,
  });

  final DocumentRepository repository;
  final VoidCallback onBackToDocuments;

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  // TODO(api): served by MockDocumentRepository until Django exposes an audit
  // log JSON API.
  late final Future<List<Document>> _documents =
      widget.repository.fetchDocuments();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(),
      body: FutureBuilder<List<Document>>(
        future: _documents,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final documents = snapshot.data!;

          // The audit view is only meaningful for a signed document; fall
          // back to the first one so the screen is never empty.
          final document = documents.firstWhere(
            (d) => d.status == DocumentStatus.signed,
            orElse: () => documents.first,
          );

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.pageMargin),
            children: [
              _BackToDocuments(onPressed: widget.onBackToDocuments),

              const SizedBox(height: AppSpacing.xs),

              const Text(
                'Audit & Vérification',
                style: AppTypography.headlineLg,
              ),

              const SizedBox(height: AppSpacing.sm),

              Text(
                document.title,
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              _ValidityBanner(document: document),

              const SizedBox(height: AppSpacing.lg),

              const _SectionTitle(
                icon: Icons.history,
                label: "Journal d'audit",
              ),

              const SizedBox(height: AppSpacing.md),

              AuditTimeline(events: document.auditTrail),

              const SizedBox(height: AppSpacing.lg),

              const _SectionTitle(
                icon: Icons.info_outline,
                label: 'Détails techniques',
              ),

              const SizedBox(height: AppSpacing.md),

              _TechnicalDetails(document: document),
            ],
          );
        },
      ),
    );
  }
}

class _BackToDocuments extends StatelessWidget {
  const _BackToDocuments({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text('RETOUR AUX DOCUMENTS'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.outline,
          padding: EdgeInsets.zero,
          textStyle: AppTypography.labelMd,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.onSurface),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTypography.headlineSm),
      ],
    );
  }
}

class _ValidityBanner extends StatelessWidget {
  const _ValidityBanner({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    const valid = AppColors.statusSigned;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            colors: [
              valid.withValues(alpha: 0.1),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: valid.withValues(alpha: 0.2),
                border: Border.all(
                  color: valid.withValues(alpha: 0.5),
                ),
              ),
              child: const Icon(
                Icons.check_circle,
                size: 32,
                color: valid,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Document Valide',
                  style: AppTypography.headlineSm.copyWith(color: valid),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.verified, size: 16, color: valid),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              'Signature authentifiée. Tous les scellés cryptographiques '
              'sont intacts et vérifiés mathématiquement.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VÉRIFICATION DU HASH',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    document.shortHash,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailEntry(label: 'IDENTIFIANT DU DOCUMENT', value: document.id),

          const _DetailDivider(),

          _DetailEntry(label: 'ALGORITHME', value: document.algorithm),

          const _DetailDivider(),

          _DetailEntry(label: 'LOCALISATION / IP', value: document.location),

          const SizedBox(height: AppSpacing.md),

          PasskeyButton.outlined(
            label: "Télécharger le rapport d'audit",
            icon: Icons.download,
            onPressed: () => showComingSoon(context, 'Rapport d\'audit'),
          ),
        ],
      ),
    );
  }
}

class _DetailEntry extends StatelessWidget {
  const _DetailEntry({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(color: AppColors.outline),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Divider(),
    );
  }
}
