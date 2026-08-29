import 'package:flutter/material.dart';

import '../data/document_repository.dart';
import '../data/signing_coordinator.dart';
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
    required this.coordinator,
    this.initialIndex = 0,
  });

  final AppSession session;
  final DocumentRepository repository;
  final SigningCoordinator coordinator;
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  // A signature changes what every tab shows, and IndexedStack keeps the
  // others alive off-screen, so they are told to refetch rather than left
  // displaying a stale document.
  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _documentsKey = GlobalKey<DocumentsScreenState>();
  final _verifyKey = GlobalKey<VerifyScreenState>();

  void _openDocuments() => setState(() => _index = 1);

  void _refreshAll() {
    _dashboardKey.currentState?.reload();
    _documentsKey.currentState?.reload();
    _verifyKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            key: _dashboardKey,
            session: widget.session,
            repository: widget.repository,
            coordinator: widget.coordinator,
            onSeeAllDocuments: _openDocuments,
            onDocumentSigned: _refreshAll,
          ),
          DocumentsScreen(
            key: _documentsKey,
            repository: widget.repository,
            coordinator: widget.coordinator,
            onDocumentSigned: _refreshAll,
          ),
          VerifyScreen(
            key: _verifyKey,
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
