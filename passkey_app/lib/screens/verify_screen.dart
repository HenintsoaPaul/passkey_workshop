import 'package:flutter/material.dart';

import '../data/document_repository.dart';
import '../models/document.dart';
import '../models/verification.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/audit_timeline.dart';

/// Audit trail and cryptographic verification.
///
/// Every verdict on this screen comes from `/api/documents/<id>/verify/`,
/// which re-runs the four conditions of §2.5 server-side. Nothing here decides
/// on its own whether a document is valid.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({
    super.key,
    required this.repository,
    required this.onBackToDocuments,
  });

  final DocumentRepository repository;
  final VoidCallback onBackToDocuments;

  @override
  State<VerifyScreen> createState() => VerifyScreenState();
}

class VerifyScreenState extends State<VerifyScreen> {
  late Future<List<Document>> _documents = widget.repository.fetchDocuments();

  Future<VerificationReport>? _report;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _documents.then(_selectInitial).catchError((_) => <Document>[]);
  }

  /// Refetches the list and the current report; called after a signature.
  void reload() {
    setState(() {
      _documents = widget.repository.fetchDocuments();
      _report = null;
      _selectedId = null;
    });

    _documents.then(_selectInitial).catchError((_) => <Document>[]);
  }

  List<Document> _selectInitial(List<Document> documents) {
    if (documents.isNotEmpty && mounted && _selectedId == null) {
      _select(documents.first);
    }

    return documents;
  }

  void _select(Document document) {
    setState(() {
      _selectedId = document.id;
      _report = widget.repository.fetchVerification(document.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(),
      body: FutureBuilder<List<Document>>(
        future: _documents,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredMessage(
              icon: Icons.cloud_off,
              message: 'Impossible de charger les documents.',
              detail: '${snapshot.error}',
              onRetry: reload,
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final documents = snapshot.data!;

          if (documents.isEmpty) {
            return const _CenteredMessage(
              icon: Icons.folder_off,
              message: 'Aucun document à vérifier.',
            );
          }

          final selected = documents.firstWhere(
            (document) => document.id == _selectedId,
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

              const SizedBox(height: AppSpacing.md),

              _DocumentPicker(
                documents: documents,
                selectedId: selected.id,
                onSelected: _select,
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                selected.title,
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              FutureBuilder<VerificationReport>(
                future: _report,
                builder: (context, reportSnapshot) {
                  if (reportSnapshot.hasError) {
                    return _ErrorBanner(
                      message: '${reportSnapshot.error}',
                    );
                  }

                  if (!reportSnapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final report = reportSnapshot.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _VerdictBanner(report: report),

                      const SizedBox(height: AppSpacing.lg),

                      const _SectionTitle(
                        icon: Icons.rule,
                        label: 'Conditions de validité',
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _ChecksCard(checks: report.checks),

                      if (report.signatures.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        const _SectionTitle(
                          icon: Icons.draw,
                          label: 'Signatures enregistrées',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SignaturesCard(signatures: report.signatures),
                      ],

                      const SizedBox(height: AppSpacing.lg),

                      const _SectionTitle(
                        icon: Icons.history,
                        label: "Journal d'audit",
                      ),

                      const SizedBox(height: AppSpacing.md),

                      if (selected.auditTrail.isEmpty)
                        const _EmptyTimeline()
                      else
                        AuditTimeline(events: selected.auditTrail),

                      const SizedBox(height: AppSpacing.lg),

                      const _SectionTitle(
                        icon: Icons.info_outline,
                        label: 'Détails techniques',
                      ),

                      const SizedBox(height: AppSpacing.md),

                      _TechnicalDetails(document: selected, report: report),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({
    required this.documents,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Document> documents;
  final String selectedId;
  final ValueChanged<Document> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: documents.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final document = documents[index];

          return ChoiceChip(
            label: Text(
              document.title,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd,
            ),
            selected: document.id == selectedId,
            onSelected: (_) => onSelected(document),
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
        Expanded(child: Text(label, style: AppTypography.headlineSm)),
      ],
    );
  }
}

/// Overall verdict. The colour and wording follow the server, so an
/// unfinished document reads as waiting and a tampered one reads as broken.
class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.report});

  final VerificationReport report;

  @override
  Widget build(BuildContext context) {
    final color = report.verdict.color;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
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
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(report.verdict.icon, size: 32, color: color),
            ),

            const SizedBox(height: AppSpacing.md),

            Text(
              report.verdict.label,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSm.copyWith(color: color),
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              report.summary,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Text(
              '${report.signedCount} sur ${report.requiredCount} '
              'signature(s) enregistrée(s)',
              style: AppTypography.labelMd.copyWith(color: color),
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
                    'EMPREINTE ACTUELLE',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    report.shortHash,
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

/// The four conditions of §2.5, each with its own pass/fail.
class _ChecksCard extends StatelessWidget {
  const _ChecksCard({required this.checks});

  final List<VerificationCheck> checks;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < checks.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1),
              ),
            _CheckRow(check: checks[i]),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final VerificationCheck check;

  @override
  Widget build(BuildContext context) {
    final color =
        check.passed ? AppColors.statusSigned : AppColors.error;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          check.passed ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: color,
        ),

        const SizedBox(width: AppSpacing.sm),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                check.label,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              if (check.detail != null && check.detail!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  check.detail!,
                  style: AppTypography.labelSm.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SignaturesCard extends StatelessWidget {
  const _SignaturesCard({required this.signatures});

  final List<SignatureReport> signatures;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < signatures.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1),
              ),
            _SignatureRow(signature: signatures[i]),
          ],
        ],
      ),
    );
  }
}

class _SignatureRow extends StatelessWidget {
  const _SignatureRow({required this.signature});

  final SignatureReport signature;

  @override
  Widget build(BuildContext context) {
    final color =
        signature.isValid ? AppColors.statusSigned : AppColors.error;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          signature.isValid ? Icons.verified_user : Icons.gpp_bad,
          size: 18,
          color: color,
        ),

        const SizedBox(width: AppSpacing.sm),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                signature.signerName.isEmpty
                    ? signature.signer
                    : signature.signerName,
                style: AppTypography.bodyMd,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                signature.signedAt != null
                    ? '${signature.algorithm ?? ''} • '
                        '${formatRelative(signature.signedAt!)}'
                    : signature.algorithm ?? '',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.outline,
                ),
              ),
              if (!signature.isValid && signature.reason != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  signature.reason!,
                  style: AppTypography.labelSm.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({required this.document, required this.report});

  final Document document;
  final VerificationReport report;

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

          _DetailEntry(
            label: 'EMPREINTE ACTUELLE',
            value: report.currentHash ?? 'illisible',
          ),

          const _DetailDivider(),

          _DetailEntry(
            label: 'EMPREINTE ENREGISTRÉE',
            value: report.storedHash ?? '—',
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
        SelectableText(
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

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(
        "Aucun événement enregistré pour ce document.",
        style: AppTypography.bodyMd.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

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
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.message,
    this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.outline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd,
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.outline,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
