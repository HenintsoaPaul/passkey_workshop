import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the private key PEM lives.
///
/// Behind an interface so tests can run the signing service without the
/// platform channel — and so the Android Keystore variant described in
/// `README.md` can replace it later without touching any caller.
abstract class KeyStorage {
  Future<String?> read(String name);

  Future<void> write(String name, String value);

  Future<void> delete(String name);
}

/// Android EncryptedSharedPreferences / iOS Keychain.
class SecureKeyStorage implements KeyStorage {
  const SecureKeyStorage();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);

  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}

/// Test double. Never used by the running app.
class InMemoryKeyStorage implements KeyStorage {
  final Map<String, String> _entries = {};

  @override
  Future<String?> read(String name) async => _entries[name];

  @override
  Future<void> write(String name, String value) async {
    _entries[name] = value;
  }

  @override
  Future<void> delete(String name) async {
    _entries.remove(name);
  }
}
