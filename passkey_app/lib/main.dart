import 'package:flutter/material.dart';

import 'app_config.dart';
import 'data/document_repository.dart';
import 'passkey_service.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'session/app_session.dart';
import 'theme/app_theme.dart';

final passkeyService = PasskeyService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppConfig.load();
  } catch (e) {
    debugPrint(
      'Config load failed, using default host: $e',
    );
  }

  try {
    await passkeyService.initialize();
  } catch (e) {
    debugPrint(
      'Credential Manager initialization failed: $e',
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _session = AppSession();

  final _repository = const MockDocumentRepository();

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignApp Passkey',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AnimatedBuilder(
        animation: _session,
        builder: (context, _) {
          // Signing in and out is state, not navigation: the root swaps
          // between the two, so neither screen has to know about the other.
          if (_session.isSignedIn) {
            return AppShell(session: _session, repository: _repository);
          }

          return AuthScreen(
            passkeyService: passkeyService,
            session: _session,
          );
        },
      ),
    );
  }
}
