import 'package:flutter/material.dart';

import '../data/document_repository.dart';
import '../models/document.dart';
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

/// Searchable list of the signed-in user's documents.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, required this.repository});

  final DocumentRepository repository;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _searchController = TextEditingController();

  // TODO(api): served by MockDocumentRepository until Django exposes a
  // documents JSON API.
  late final Future<List<Document>> _documents =
      widget.repository.fetchDocuments();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

          final documents = _filter(snapshot.data!);

          return ListView(
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
                const _EmptyResults()
              else
                for (final document in documents) ...[
                  _DocumentCard(document: document),
                  const SizedBox(height: AppSpacing.md),
                ],
            ],
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
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 32,
            color: AppColors.outline,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Aucun document ne correspond à cette recherche.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd,
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => DocumentDetailScreen(document: document),
        ),
      ),
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  formatShortDate(document.createdAt),
                  style: AppTypography.labelMd,
                ),
              ),
              ..._actionsFor(context, document),
            ],
          ),
        ],
      ),
    );
  }

  /// Draft documents offer editing; the rest offer history and download,
  /// matching the mockup.
  List<Widget> _actionsFor(BuildContext context, Document document) {
    if (document.status == DocumentStatus.draft) {
      return [
        CircleIconButton(
          icon: Icons.edit,
          tooltip: 'Modifier',
          filled: true,
          onPressed: () => showComingSoon(context, 'Modification'),
        ),
      ];
    }

    return [
      CircleIconButton(
        icon: Icons.history,
        tooltip: 'Historique',
        filled: true,
        onPressed: () => showComingSoon(context, 'Historique'),
      ),
      const SizedBox(width: AppSpacing.sm),
      CircleIconButton(
        icon: Icons.download,
        tooltip: 'Télécharger',
        filled: true,
        onPressed: () => showComingSoon(context, 'Téléchargement'),
      ),
    ];
  }
}
