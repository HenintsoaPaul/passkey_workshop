import 'package:flutter/material.dart';

import '../data/document_repository.dart';
import '../session/app_session.dart';
import '../widgets/app_bottom_nav.dart';
import 'dashboard_screen.dart';
import 'documents_screen.dart';
import 'settings_screen.dart';
import 'verify_screen.dart';

/// Tab host for the four bottom-navigation destinations.
///
/// An [IndexedStack] keeps each tab's scroll position and state alive when
/// switching between them.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.session,
    required this.repository,
    this.initialIndex = 0,
  });

  final AppSession session;
  final DocumentRepository repository;
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  void _openDocuments() => setState(() => _index = 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            session: widget.session,
            repository: widget.repository,
            onSeeAllDocuments: _openDocuments,
          ),
          DocumentsScreen(repository: widget.repository),
          VerifyScreen(
            repository: widget.repository,
            onBackToDocuments: _openDocuments,
          ),
          SettingsScreen(session: widget.session),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        onSelected: (index) => setState(() => _index = index),
      ),
    );
  }
}
