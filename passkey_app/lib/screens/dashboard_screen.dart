import 'package:flutter/material.dart';

import '../data/document_repository.dart';
import '../data/signing_coordinator.dart';
import '../models/document.dart';
import '../session/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../widgets/app_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/status_badge.dart';
import 'document_detail_screen.dart';

/// Landing tab: greeting, passkey status, counters, and signature tasks.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.coordinator,
    required this.onSeeAllDocuments,
    this.onDocumentSigned,
  });

  final AppSession session;
  final DocumentRepository repository;
  final SigningCoordinator coordinator;
  final VoidCallback onSeeAllDocuments;
  final VoidCallback? onDocumentSigned;

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Document>> _documents = widget.repository.fetchDocuments();

  Future<void> reload() async {
    setState(() => _documents = widget.repository.fetchDocuments());

    // Callers fire this without awaiting, so a failure is reported through the
    // FutureBuilder rather than escaping as an unhandled error.
    await _documents.catchError((Object _) => <Document>[]);
  }

  Future<void> _open(Document document) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DocumentDetailScreen(
          document: document,
          repository: widget.repository,
          coordinator: widget.coordinator,
          onChanged: () {
            reload();
            widget.onDocumentSigned?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(),
      body: FutureBuilder<List<Document>>(
        future: _documents,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadFailure(error: '${snapshot.error}', onRetry: reload);
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final documents = snapshot.data!;

          // "En attente" counts what this user still has to do, not every
          // unfinished document.
          final awaiting = documents.where((d) => d.canSign).toList();

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.pageMargin),
              children: [
                _Welcome(username: widget.session.displayName),

                const SizedBox(height: AppSpacing.lg),

                AnimatedBuilder(
                  animation: widget.session,
                  builder: (context, _) => _PasskeyStatusCard(
                    fingerprint: widget.session.signingKeyFingerprint,
                  ),
                ),

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
                        value: '${awaiting.length}',
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

                if (documents.isEmpty)
                  const _NoTasks()
                else
                  for (final document in documents) ...[
                    _TaskCard(
                      document: document,
                      onOpen: () => _open(document),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
              ],
            ),
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

/// Reports whether this device has a signing key registered, since without one
/// no signature is possible.
class _PasskeyStatusCard extends StatelessWidget {
  const _PasskeyStatusCard({required this.fingerprint});

  final String? fingerprint;

  static const _pendingLabel = 'Génération à la première signature';

  String get _shortFingerprint {
    final value = fingerprint ?? '';

    return value.length <= 12 ? value : '${value.substring(0, 12)}…';
  }

  @override
  Widget build(BuildContext context) {
    final ready = fingerprint != null;

    return AppCard(
      child: Row(
        children: [
          Icon(
            Icons.fingerprint,
            size: 28,
            color: ready ? AppColors.primary : AppColors.statusWaiting,
          ),

          const SizedBox(width: AppSpacing.gutter),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clé de signature',
                  style: AppTypography.headlineSm,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ready ? 'RSA-2048 · $_shortFingerprint' : _pendingLabel,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(
                    color: ready
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  ready ? AppColors.statusSigned : AppColors.statusWaiting,
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

class _NoTasks extends StatelessWidget {
  const _NoTasks();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.task_alt,
            size: 20,
            color: AppColors.statusSigned,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "Aucun document ne vous est affecté pour l'instant.",
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.document, required this.onOpen});

  final Document document;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final signed = document.hasSigned;

    return AppCard(
      onTap: onOpen,
      opacity: signed ? 0.8 : 1,
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
                      signed ? Icons.done_all : Icons.schedule,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        signed
                            ? 'Signé ${formatRelative(document.updatedAt)}'
                            : 'Reçu ${formatRelative(document.updatedAt)}',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMd,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              if (document.canSign)
                FilledButton(
                  onPressed: onOpen,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.key, size: 18),
                      SizedBox(width: AppSpacing.sm),
                      Text('Signer'),
                    ],
                  ),
                )
              else
                Text(
                  '${document.signedCount}/${document.signers.length} signé(s)',
                  style: AppTypography.labelMd,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 32, color: AppColors.outline),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Impossible de joindre le serveur.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.labelSm.copyWith(color: AppColors.outline),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
