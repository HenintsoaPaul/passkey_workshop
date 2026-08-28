import 'dart:convert';

import 'package:http/http.dart' as http;

class Api {

  static String? _sessionCookie;

  static const baseUrl = 'https://socks-aspects-cinema-continue.trycloudflare.com';

  static Future<Map<String, dynamic>> registerOptions(
    String username,
  ) async {
    final response = await _post(
      '/chiffrement_app/register/options/',
      {
        'username': username,
      },
    );

    _check(response);

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> registerVerify(
    String username,
    Map<String, dynamic> credential,
  ) async {
    final response = await _post(
      '/chiffrement_app/register/verify/',
      {
        'username': username,
        'credential': credential,
      },
    );

    _check(response);

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> loginOptions(
    String username,
  ) async {
    final response = await _post(
      '/chiffrement_app/login/options/',
      {
        'username': username,
      },
    );

    _check(response);

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> loginVerify(
    Map<String, dynamic> credential,
  ) async {
    final response = await _post(
      '/chiffrement_app/login/verify/',
      {
        'credential': credential,
      },
    );

    _check(response);

    return jsonDecode(response.body);
  }

  static void _check(http.Response response) {
    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }
  }

  static Future<http.Response> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final headers = {
      'Content-Type': 'application/json',
      'Cookie': ?_sessionCookie,
    };

    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );

    final setCookie = response.headers['set-cookie'];

    if (setCookie != null) {
      _sessionCookie = setCookie.split(';').first;
    }

    return response;
  }
}