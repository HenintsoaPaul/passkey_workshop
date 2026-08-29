import 'package:passkey_app/crypto/key_storage.dart';
import 'package:passkey_app/crypto/local_signing_service.dart';
import 'package:passkey_app/data/document_repository.dart';
import 'package:passkey_app/data/signing_coordinator.dart';

/// A coordinator wired to fixtures, for widget tests that render screens
/// without ever completing a signature.
SigningCoordinator buildTestCoordinator([
  DocumentRepository repository = const MockDocumentRepository(),
]) {
  return SigningCoordinator(
    repository: repository,
    signingService: LocalSigningService(storage: InMemoryKeyStorage()),
    confirmWithPasskey: (_) async => const {},
  );
}
