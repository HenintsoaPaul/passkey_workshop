import 'package:flutter/foundation.dart';

/// Who is signed in, plus the running trace of passkey ceremony steps.
///
/// The log was previously local to the proof-of-concept page; it lives here so
/// the auth screen can write to it and the settings screen can display it.
class AppSession extends ChangeNotifier {
  String? _username;

  final List<String> _logs = [];

  String? get username => _username;

  bool get isSignedIn => _username != null;

  /// Newest entry first.
  List<String> get logs => List.unmodifiable(_logs);

  void signIn(String username) {
    _username = username;
    notifyListeners();
  }

  void signOut() {
    _username = null;
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
