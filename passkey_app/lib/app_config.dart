import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class AppConfig {
  AppConfig._();

  static String apiBaseUrl =
      'https://socks-aspects-cinema-continue.trycloudflare.com';

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/config.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;

    apiBaseUrl = data['apiBaseUrl'] as String;
  }
}
