import 'package:flutter/material.dart';

import 'api.dart';
import 'app_config.dart';
import 'crypto/local_signing_service.dart';
import 'crypto/signing_service.dart';
import 'data/document_repository.dart';
import 'data/signing_coordinator.dart';
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

  // Prefer the hardware Keystore; fall back to the in-app backend wherever it
  // is unavailable, so signing works either way.
  final signingService = await resolveSigningService();

  runApp(MyApp(signingService: signingService));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.repository, this.signingService});

  /// Overridable so tests can run against fixtures instead of a live server.
  final DocumentRepository? repository;

  final SigningService? signingService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _session = AppSession();

  late final DocumentRepository _repository =
      widget.repository ?? const HttpDocumentRepository();

  late final SigningService _signingService =
      widget.signingService ?? LocalSigningService();

  late final SigningCoordinator _coordinator = SigningCoordinator(
    repository: _repository,
    confirmWithPasskey: (options) async =>
        (await passkeyService.authenticate(options)).toJson(),
    signingService: _signingService,
    session: _session,
  );

  @override
  void initState() {
    super.initState();

    // A rejected session cannot be recovered from inside a tab, so send the
    // user back to the sign-in screen rather than leaving every screen
    // showing the same error.
    Api.onUnauthenticated = () {
      if (mounted && _session.isSignedIn) {
        _session.addLog('Session refusée par le serveur, reconnexion requise');
        _session.signOut();
      }
    };
  }

  @override
  void dispose() {
    Api.onUnauthenticated = null;
    _session.dispose();
    super.dispose();
  }

  /// Registers the device's public key as soon as the user is signed in.
  ///
  /// Generating RSA-2048 takes a few seconds, so paying for it here keeps the
  /// first signature responsive. A failure is logged and retried at signing
  /// time rather than blocking the session.
  Future<void> _prepareSigningKey() async {
    try {
      _session.addLog('Clé de signature : ${_signingService.backendLabel}');
      _session.setSigningKeyFingerprint(
        await _coordinator.ensureKeyRegistered(),
      );
      _session.setSigningBackend(_signingService.backendLabel);
    } catch (e) {
      _session.addLog('Signing key registration failed: $e');
    }
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
            return AppShell(
              session: _session,
              repository: _repository,
              coordinator: _coordinator,
            );
          }

          return AuthScreen(
            passkeyService: passkeyService,
            session: _session,
            onSignedIn: _prepareSigningKey,
          );
        },
      ),
    );
  }
}
