import 'package:flutter/material.dart';
import 'package:passkey_app/passkey_page.dart';

import 'app_config.dart';
import 'passkey_service.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Passkey Signature App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: PasskeyPage(passkeyService: passkeyService)
    );
  }
}