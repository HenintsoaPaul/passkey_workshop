import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:passkey_app/data/document_repository.dart';
import 'package:passkey_app/screens/app_shell.dart';
import 'package:passkey_app/session/app_session.dart';
import 'package:passkey_app/theme/app_theme.dart';

Future<void> pumpShell(WidgetTester tester, AppSession session) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: AppShell(
        session: session,
        repository: const MockDocumentRepository(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// Selects a tab by its bottom-navigation label.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

int? currentTabIndex(WidgetTester tester) {
  return tester.widget<IndexedStack>(find.byType(IndexedStack)).index;
}

void main() {
  testWidgets('the bottom bar exposes the four destinations',
      (WidgetTester tester) async {
    await pumpShell(tester, AppSession()..signIn('henintsoa'));

    for (final label in ['Dashboard', 'Documents', 'Verify', 'Settings']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('each tab renders its own heading when selected',
      (WidgetTester tester) async {
    await pumpShell(tester, AppSession()..signIn('henintsoa'));

    // Unselected tabs are kept offstage by IndexedStack, so each one has to
    // be visited to prove it builds.
    expect(find.text('Bienvenue, henintsoa !'), findsOneWidget);

    await openTab(tester, 'Documents');
    expect(find.text('Documents récents'), findsOneWidget);

    await openTab(tester, 'Verify');
    expect(find.text('Audit & Vérification'), findsOneWidget);

    await openTab(tester, 'Settings');
    expect(find.text('Paramètres'), findsOneWidget);
  });

  testWidgets('tapping a destination moves the selection',
      (WidgetTester tester) async {
    await pumpShell(tester, AppSession()..signIn('henintsoa'));

    expect(currentTabIndex(tester), 0);

    await openTab(tester, 'Settings');
    expect(currentTabIndex(tester), 3);

    await openTab(tester, 'Documents');
    expect(currentTabIndex(tester), 1);
  });

  testWidgets('the dashboard counters follow the repository',
      (WidgetTester tester) async {
    await pumpShell(tester, AppSession()..signIn('henintsoa'));

    final documents = await const MockDocumentRepository().fetchDocuments();
    final pending =
        documents.where((d) => d.status.name == 'pending').length;

    expect(find.text('Mes Documents'), findsOneWidget);
    expect(find.text('En Attente'), findsOneWidget);
    expect(find.text('${documents.length}'), findsOneWidget);
    expect(find.text('$pending'), findsOneWidget);
  });

  testWidgets('the documents search filters the list',
      (WidgetTester tester) async {
    await pumpShell(tester, AppSession()..signIn('henintsoa'));
    await openTab(tester, 'Documents');

    // Only the first card is within the test viewport; the list is lazy.
    expect(find.text('Contrat de Prestation S.A.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'licence');
    await tester.pumpAndSettle();

    expect(find.text('Contrat de Prestation S.A.'), findsNothing);
    expect(find.text('Licence Logicielle Entreprise'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(
      find.text('Aucun document ne correspond à cette recherche.'),
      findsOneWidget,
    );
  });

  testWidgets('opening a document shows its detail screen',
      (WidgetTester tester) async {
    await pumpShell(tester, AppSession()..signIn('henintsoa'));
    await openTab(tester, 'Documents');

    await tester.tap(find.text('Contrat de Prestation S.A.'));
    await tester.pumpAndSettle();

    expect(find.text('Propriétaire'), findsOneWidget);
    expect(find.text('SHA-256'), findsOneWidget);
    expect(find.text('Progression des signatures'), findsOneWidget);
    expect(find.text('Signer le document'), findsOneWidget);
  });

  testWidgets('every tab lays out without overflowing a phone-width screen',
      (WidgetTester tester) async {
    // The default 800x600 test surface is wider than any phone and hides
    // horizontal overflow, which is how the bottom bar first slipped through.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpShell(tester, AppSession()..signIn('henintsoa'));

    for (final label in ['Documents', 'Verify', 'Settings', 'Dashboard']) {
      await openTab(tester, label);

      // A RenderFlex overflow is reported as an exception during layout, so
      // reaching here with a clean tester means the tab fits.
      expect(tester.takeException(), isNull, reason: label);
    }

    // The detail screen is a pushed route, so it is not covered by the loop.
    await openTab(tester, 'Documents');
    await tester.tap(find.text('Contrat de Prestation S.A.'));
    await tester.pumpAndSettle();

    expect(find.text('Signer le document'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'document detail');
  });

  testWidgets('the settings tab shows the signed-in username',
      (WidgetTester tester) async {
    await pumpShell(tester, AppSession()..signIn('henintsoa'));
    await openTab(tester, 'Settings');

    expect(find.text('henintsoa'), findsOneWidget);
    expect(find.text('Connecté via passkey'), findsOneWidget);
  });
}
