import 'package:flutter/foundation.dart';

/// Who is signed in, plus the running trace of passkey ceremony steps.
///
/// The log was previously local to the proof-of-concept page; it lives here so
/// the auth screen can write to it and the settings screen can display it.
class AppSession extends ChangeNotifier {
  String? _username;
  String? _displayName;
  String? _signingKeyFingerprint;
  String? _signingBackend;

  final List<String> _logs = [];

  String? get username => _username;

  /// The profile name from the server, falling back to the username.
  String? get displayName => _displayName ?? _username;

  /// Fingerprint of the RSA public key this device registered, once known.
  String? get signingKeyFingerprint => _signingKeyFingerprint;

  /// Where the private key is held, e.g. the Android Keystore.
  String? get signingBackend => _signingBackend;

  bool get isSignedIn => _username != null;

  /// Newest entry first.
  List<String> get logs => List.unmodifiable(_logs);

  void signIn(String username, {String? displayName}) {
    _username = username;
    _displayName = displayName;
    notifyListeners();
  }

  void signOut() {
    _username = null;
    _displayName = null;
    _signingKeyFingerprint = null;
    _signingBackend = null;
    notifyListeners();
  }

  void setDisplayName(String? name) {
    if (name == null || name.isEmpty || _displayName == name) {
      return;
    }

    _displayName = name;
    notifyListeners();
  }

  void setSigningBackend(String? backend) {
    if (_signingBackend == backend) {
      return;
    }

    _signingBackend = backend;
    notifyListeners();
  }

  void setSigningKeyFingerprint(String? fingerprint) {
    if (_signingKeyFingerprint == fingerprint) {
      return;
    }

    _signingKeyFingerprint = fingerprint;
    notifyListeners();
  }

  void addLog(String text) {
    _logs.insert(0, '${DateTime.now().toLocal()} - $text');
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }
}
