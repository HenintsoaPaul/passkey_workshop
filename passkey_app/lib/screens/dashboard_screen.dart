import 'package:flutter/material.dart';

import '../data/document_repository.dart';
import '../models/document.dart';
import '../session/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../utils/placeholders.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/status_badge.dart';
import 'document_detail_screen.dart';

/// Landing tab: greeting, passkey status, counters, and signature tasks.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.onSeeAllDocuments,
  });

  final AppSession session;
  final DocumentRepository repository;
  final VoidCallback onSeeAllDocuments;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // TODO(api): served by MockDocumentRepository until Django exposes a
  // documents JSON API.
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
          final pending = documents
              .where((d) => d.status == DocumentStatus.pending)
              .length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.pageMargin),
            children: [
              _Welcome(username: widget.session.username),

              const SizedBox(height: AppSpacing.lg),

              const _PasskeyStatusCard(),

              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.folder_open,
                      iconColor: AppColors.secondaryFixed,
                      value: '${documents.length}',
                      label: 'Mes Documents',
                      onTap: widget.onSeeAllDocuments,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gutter),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.pending_actions,
                      iconColor: AppColors.error,
                      value: '$pending',
                      label: 'En Attente',
                      highlight: true,
                      onTap: widget.onSeeAllDocuments,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              const Text(
                'Tâches de Signature',
                style: AppTypography.headlineSm,
              ),

              const SizedBox(height: AppSpacing.md),

              for (final document in documents) ...[
                _TaskCard(document: document),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.username});

  final String? username;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenue, ${username ?? 'invité'} !',
          style: AppTypography.headlineLg,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Voici un résumé de votre activité de signature.',
          style: AppTypography.bodyMd,
        ),
      ],
    );
  }
}

class _PasskeyStatusCard extends StatelessWidget {
  const _PasskeyStatusCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.fingerprint,
            size: 28,
            color: AppColors.primary,
          ),

          const SizedBox(width: AppSpacing.gutter),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statut Passkey',
                  style: AppTypography.headlineSm,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Prêt pour l'authentification",
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.statusSigned,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final VoidCallback onTap;

  /// Adds the subtle error-tinted wash the "En Attente" card has.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(height: AppSpacing.sm),
        Text(value, style: AppTypography.headlineMd),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: AppTypography.labelMd),
      ],
    );

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: highlight
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.error.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              )
            : null,
        child: content,
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.document});

  final Document document;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DocumentDetailScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSigned = document.status == DocumentStatus.signed;

    return AppCard(
      onTap: () => _open(context),
      opacity: isSigned ? 0.8 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Text(
                    document.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headlineSm,
                  ),
                ),
              ),
              StatusBadge.document(document.status),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isSigned ? Icons.done_all : Icons.schedule,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        isSigned
                            ? 'Terminé ${formatRelative(document.updatedAt)}'
                            : 'Reçu ${formatRelative(document.updatedAt)}',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMd,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              if (isSigned)
                CircleIconButton(
                  icon: Icons.download,
                  tooltip: 'Télécharger',
                  onPressed: () =>
                      showComingSoon(context, 'Téléchargement'),
                )
              else
                FilledButton(
                  onPressed: () => _open(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.key, size: 18),
                      SizedBox(width: AppSpacing.sm),
                      Text('Signer'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
