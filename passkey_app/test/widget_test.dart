import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:passkey_app/data/document_repository.dart';
import 'package:passkey_app/main.dart';
import 'package:passkey_app/passkey_service.dart';
import 'package:passkey_app/screens/app_shell.dart';
import 'package:passkey_app/screens/auth_screen.dart';
import 'package:passkey_app/session/app_session.dart';
import 'package:passkey_app/theme/app_theme.dart';

import 'support/test_coordinator.dart';

void main() {
  testWidgets('AuthScreen renders the username field and both passkey actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(repository: MockDocumentRepository()),
    );

    expect(find.text('SignApp Passkey'), findsOneWidget);
    expect(find.text("NOM D'UTILISATEUR"), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    expect(find.text('Se connecter avec une passkey'), findsOneWidget);
    expect(find.text('Créer une passkey'), findsOneWidget);
    expect(find.text('Voir les journaux'), findsOneWidget);
  });

  testWidgets('AuthScreen rejects an empty username without calling the API',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(repository: MockDocumentRepository()),
    );

    await tester.tap(find.text('Se connecter avec une passkey'));
    await tester.pump();

    // The guard runs before any network call, so no exception escapes here.
    expect(
      find.text("Saisissez d'abord un nom d'utilisateur."),
      findsOneWidget,
    );
  });

  testWidgets('The logs sheet opens and reports that it is empty',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(repository: MockDocumentRepository()),
    );

    await tester.tap(find.text('Voir les journaux'));
    await tester.pumpAndSettle();

    expect(find.text('Journaux de débogage'), findsOneWidget);
    expect(find.text('Aucun journal pour le moment'), findsOneWidget);
  });

  testWidgets('the session state swaps the root between auth and the shell',
      (WidgetTester tester) async {
    final session = AppSession();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AnimatedBuilder(
          animation: session,
          builder: (context, _) => session.isSignedIn
              ? AppShell(
                  session: session,
                  repository: const MockDocumentRepository(),
                  coordinator: buildTestCoordinator(),
                )
              : AuthScreen(
                  passkeyService: PasskeyService(),
                  session: session,
                ),
        ),
      ),
    );

    expect(find.text('Se connecter avec une passkey'), findsOneWidget);

    session.signIn('henintsoa');
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue, henintsoa !'), findsOneWidget);

    // Signing out has to bring the auth screen back; an earlier version
    // popped the navigator instead and silently did nothing.
    session.signOut();
    await tester.pumpAndSettle();

    expect(find.text('Se connecter avec une passkey'), findsOneWidget);
  });
}
