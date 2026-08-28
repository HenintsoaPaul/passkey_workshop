import 'package:flutter/material.dart';
import 'package:passkey_app/passkey_page.dart';

import 'passkey_service.dart';

final passkeyService = PasskeyService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      home: PasskeyPage()
    );
  }
}