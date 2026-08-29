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
import '../widgets/status_badge.dart';
import 'document_detail_screen.dart';

/// Searchable list of the documents assigned to the signed-in user.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    super.key,
    required this.repository,
    required this.coordinator,
    this.onDocumentSigned,
  });

  final DocumentRepository repository;
  final SigningCoordinator coordinator;

  /// Lets the shell refresh its other tabs when a signature lands here.
  final VoidCallback? onDocumentSigned;

  @override
  State<DocumentsScreen> createState() => DocumentsScreenState();
}

class DocumentsScreenState extends State<DocumentsScreen> {
  final _searchController = TextEditingController();

  late Future<List<Document>> _documents = widget.repository.fetchDocuments();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() => _documents = widget.repository.fetchDocuments());

    // Callers fire this without awaiting, so a failure is reported through the
    // FutureBuilder rather than escaping as an unhandled error.
    await _documents.catchError((Object _) => <Document>[]);
  }

  List<Document> _filter(List<Document> documents) {
    if (_query.isEmpty) {
      return documents;
    }

    final query = _query.toLowerCase();

    return documents.where((document) {
      return document.title.toLowerCase().contains(query) ||
          document.description.toLowerCase().contains(query);
    }).toList();
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

          final documents = _filter(snapshot.data!);

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.pageMargin),
              children: [
                _SearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                ),

                const SizedBox(height: AppSpacing.lg),

                const Text(
                  'Documents récents',
                  style: AppTypography.headlineSm,
                ),

                const SizedBox(height: AppSpacing.md),

                if (documents.isEmpty)
                  _EmptyResults(hasQuery: _query.isNotEmpty)
                else
                  for (final document in documents) ...[
                    _DocumentCard(
                      document: document,
                      onTap: () => _open(document),
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTypography.bodyMd,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Rechercher un document...',
          fillColor: AppColors.card,
          prefixIcon: Icon(Icons.search, size: 20),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            hasQuery ? Icons.search_off : Icons.folder_off,
            size: 32,
            color: AppColors.outline,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasQuery
                ? 'Aucun document ne correspond à cette recherche.'
                : "Aucun document ne vous est affecté pour l'instant.",
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd,
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
              'Impossible de charger vos documents.',
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document, required this.onTap});

  final Document document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: AppTypography.headlineSm,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        document.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
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
                child: Text(
                  formatShortDate(document.createdAt),
                  style: AppTypography.labelMd,
                ),
              ),

              // The signature count says more here than a row of icon buttons
              // whose actions live on the web side.
              Text(
                '${document.signedCount}/${document.signers.length} signé(s)',
                style: AppTypography.labelMd.copyWith(
                  color: document.canSign
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
              ),

              const SizedBox(width: AppSpacing.xs),

              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
