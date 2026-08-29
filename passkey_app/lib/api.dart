import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'app_config.dart';

/// A failure the server described, as opposed to a transport error.
///
/// The API answers with `{"error": code, "detail": message}`, and the UI needs
/// to tell those cases apart — "you already signed" and "the network is down"
/// deserve different words on screen.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  /// The session expired or was never established; the app must sign in again.
  bool get isUnauthenticated => statusCode == 401;

  @override
  String toString() => message;
}

class Api {
  /// Cookies the server has set, by name.
  ///
  /// A jar rather than a single string: signing in makes Django rotate the
  /// CSRF token as well as the session, so `login/verify/` answers with two
  /// Set-Cookie headers and keeping only one of them loses the session.
  static final Map<String, String> _cookies = {};

  static String get baseUrl => AppConfig.apiBaseUrl;

  /// Called when the server rejects the session.
  ///
  /// Set by the app so an expired or missing session sends the user back to
  /// the sign-in screen, instead of leaving every tab showing an error it
  /// cannot recover from.
  static void Function()? onUnauthenticated;

  /// Drops every cookie. Called on sign-out so the next user does not inherit
  /// the previous one's session.
  static void clearSession() {
    _cookies.clear();
  }

  // ============ Passkey ceremonies ============

  /// Begins enrolling a passkey.
  ///
  /// Takes the account password: enrolling creates a credential that logs in
  /// without a password ever again, so the server has to know who is asking.
  /// It is the only call that ever sends one.
  static Future<Map<String, dynamic>> registerOptions(
    String username,
    String password,
  ) async {
    final response = await _post(
      '/chiffrement_app/register/options/',
      {
        'username': username,
        'password': password,
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

  // ============ Identity and keys ============

  static Future<Map<String, dynamic>> me() => _getJson('/api/me/');

  /// Registers the public half of the device key pair.
  ///
  /// The only key material this app ever sends. The server rejects anything
  /// that parses as a private key, so a mistake here fails loudly.
  static Future<Map<String, dynamic>> registerSigningKey(
    String publicKeyPem,
  ) async {
    final response = await _post('/api/keys/', {'publicKeyPem': publicKeyPem});

    _check(response);

    return jsonDecode(response.body);
  }

  // ============ Documents ============

  static Future<List<dynamic>> fetchDocuments() async {
    final data = await _getJson('/api/documents/');

    return data['documents'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> fetchDocument(String id) =>
      _getJson('/api/documents/$id/');

  /// The exact bytes the signature will cover.
  static Future<Uint8List> downloadDocument(String id) async {
    final response = await _get('/api/documents/$id/file/');

    _check(response);

    return response.bodyBytes;
  }

  static Future<Map<String, dynamic>> fetchVerification(String id) =>
      _getJson('/api/documents/$id/verify/');

  // ============ Signing ============

  /// Asks for the one-shot passkey challenge that authorizes this signature.
  ///
  /// [documentHash] is what the phone computed from the downloaded bytes; the
  /// server refuses the challenge if it disagrees.
  static Future<Map<String, dynamic>> signChallenge(
    String id,
    String documentHash,
  ) async {
    final response = await _post(
      '/api/documents/$id/sign/challenge/',
      {'documentHash': documentHash},
    );

    _check(response);

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> submitSignature(
    String id, {
    required int challengeId,
    required Map<String, dynamic> credential,
    required String signature,
  }) async {
    final response = await _post(
      '/api/documents/$id/sign/',
      {
        'challengeId': challengeId,
        'credential': credential,
        'signature': signature,
      },
    );

    _check(response);

    return jsonDecode(response.body);
  }

  // ============ Transport ============

  static Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _get(path);

    _check(response);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final error = _errorFrom(response);

    if (error.isUnauthenticated) {
      clearSession();
      onUnauthenticated?.call();
    }

    throw error;
  }

  static ApiException _errorFrom(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      return ApiException(
        statusCode: response.statusCode,
        code: body['error'] as String? ?? 'http_error',
        message: body['detail'] as String? ??
            body['error'] as String? ??
            'HTTP ${response.statusCode}',
      );
    } catch (_) {
      // Not a JSON error envelope: a proxy page, an HTML 500, an empty body.
      return ApiException(
        statusCode: response.statusCode,
        code: 'http_error',
        message: 'HTTP ${response.statusCode}: ${response.body}',
      );
    }
  }

  static Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    if (_cookies.isNotEmpty) {
      headers['Cookie'] = _cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }

    return headers;
  }

  static void _captureCookie(http.BaseResponse response) {
    for (final header in _splitSetCookie(response.headers['set-cookie'])) {
      // Everything after the first ';' is attributes (Path, HttpOnly, …).
      final pair = header.split(';').first.trim();
      final separator = pair.indexOf('=');

      if (separator > 0) {
        _cookies[pair.substring(0, separator)] = pair.substring(separator + 1);
      }
    }
  }

  /// Recovers the individual cookies from a joined Set-Cookie header.
  ///
  /// `package:http` collapses repeated headers into one comma-separated
  /// string, and a cookie's own `expires=Fri, 11 Sep 2026 …` attribute
  /// contains a comma too — so split only at a comma that actually starts a
  /// new `name=value` pair.
  static List<String> _splitSetCookie(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    return raw.split(RegExp(r',(?=[^;=]+=)'));
  }

  static Future<http.Response> _get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
    );

    _captureCookie(response);

    return response;
  }

  static Future<http.Response> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(json: true),
      body: jsonEncode(body),
    );

    _captureCookie(response);

    return response;
  }
}
