import 'package:credential_manager/credential_manager.dart';

class PasskeyService {
  PasskeyService()
      : _credentialManager = CredentialManager();

  final CredentialManager _credentialManager;

  Future<void> initialize() async {
    if (!_credentialManager.isSupportedPlatform) {
      throw StateError(
        'Credential Manager is not supported on this platform.',
      );
    }

    if (!_credentialManager.isGmsAvailable) {
      throw StateError(
        'Google Play Services is not available on this device.',
      );
    }

    await _credentialManager.init(
      preferImmediatelyAvailableCredentials: false,
    );
  }

  Future<PublicKeyCredential> createPasskey(
    Map<String, dynamic> options,
  ) async {
    final request =
        CredentialCreationOptions.fromJson(options);

    return _credentialManager.savePasskeyCredentials(
      request: request,
    );
  }

  Future<PublicKeyCredential> authenticate(
    Map<String, dynamic> options,
  ) async {
    final request =
        CredentialLoginOptions.fromJson(options);

    final credentials =
        await _credentialManager.getCredentials(
      passKeyOption: request,
      fetchOptions: FetchOptionsAndroid(
        passKey: true,
      ),
    );

    final credential = credentials.publicKeyCredential;

    if (credential == null) {
      throw StateError(
        'No passkey credential was returned.',
      );
    }

    return credential;
  }

  /// Useful when debugging the device/environment.
  bool get isSupported =>
      _credentialManager.isSupportedPlatform;

  bool get isGooglePlayServicesAvailable =>
      _credentialManager.isGmsAvailable;
}