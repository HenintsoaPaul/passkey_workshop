import 'dart:typed_data';

import '../crypto/signing_service.dart';
import '../models/document.dart';
import '../session/app_session.dart';
import 'document_repository.dart';

/// Runs the WebAuthn assertion for [options] and returns the credential JSON.
///
/// A function rather than the `PasskeyService` itself, so this file has no
/// dependency on the platform channel and the flow can be tested end to end.
typedef PasskeyAuthenticator = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> options,
);

/// Progress of a signature, so the UI can say what is happening rather than
/// spinning silently through several seconds of network and crypto.
enum SigningStep {
  downloading('Téléchargement du document…'),
  hashing('Calcul de l\'empreinte SHA-256…'),
  requestingChallenge('Préparation de la confirmation…'),
  confirming('Confirmation par passkey…'),
  signing('Signature avec votre clé privée…'),
  submitting('Envoi de la signature…');

  const SigningStep(this.label);

  final String label;
}

/// The document as the phone sees it, just before signing.
class SigningPreview {
  const SigningPreview({required this.bytes, required this.documentHash});

  final Uint8List bytes;

  /// SHA-256 computed here, from the downloaded bytes — not copied from the
  /// server's `fileHash`.
  final String documentHash;
}

/// Raised when the digest computed on the phone disagrees with the server's.
class DocumentMismatchException implements Exception {
  const DocumentMismatchException(this.localHash, this.serverHash);

  final String localHash;
  final String? serverHash;

  @override
  String toString() =>
      "L'empreinte calculée sur cet appareil ne correspond pas à celle du "
      'serveur. Le document a peut-être changé.';
}

/// Runs the five steps of §2.4 in order.
///
/// The passkey confirmation comes before the RSA signature on purpose: it is
/// what authorizes the operation, and the server refuses the signature unless
/// the assertion it issued the challenge for checks out.
class SigningCoordinator {
  const SigningCoordinator({
    required this.repository,
    required this.confirmWithPasskey,
    required this.signingService,
    this.session,
  });

  final DocumentRepository repository;
  final PasskeyAuthenticator confirmWithPasskey;
  final SigningService signingService;

  /// Optional: used only to trace the ceremony into the debug log.
  final AppSession? session;

  /// Makes sure the server knows this device's public key.
  ///
  /// Generates the pair on first call, which takes a few seconds; calling it
  /// right after sign-in keeps that cost off the first signature.
  Future<String?> ensureKeyRegistered() async {
    final alreadyExists = await signingService.hasKeyPair();

    if (!alreadyExists) {
      _log('Génération de la paire RSA-2048 sur l\'appareil');
    }

    final publicKeyPem = await signingService.ensurePublicKeyPem();
    final fingerprint = await repository.registerSigningKey(publicKeyPem);

    _log('Clé publique enregistrée (${fingerprint ?? 'sans empreinte'})');

    return fingerprint;
  }

  /// Downloads the document and hashes it locally, so the user can be shown
  /// exactly what they are about to sign before any prompt appears.
  Future<SigningPreview> prepare(
    Document document, {
    void Function(SigningStep step)? onStep,
  }) async {
    onStep?.call(SigningStep.downloading);
    final bytes = await repository.downloadDocument(document.id);

    onStep?.call(SigningStep.hashing);
    final documentHash = signingService.digestOf(bytes);

    _log('Empreinte locale : $documentHash');

    if (document.fileHash.isNotEmpty && document.fileHash != documentHash) {
      throw DocumentMismatchException(documentHash, document.fileHash);
    }

    return SigningPreview(bytes: bytes, documentHash: documentHash);
  }

  /// Confirm with the passkey, sign the digest, and send the signature.
  Future<SignatureOutcome> sign(
    Document document,
    SigningPreview preview, {
    void Function(SigningStep step)? onStep,
  }) async {
    await ensureKeyRegistered();

    onStep?.call(SigningStep.requestingChallenge);
    final challenge = await repository.requestSignChallenge(
      document.id,
      preview.documentHash,
    );

    final challengeId = challenge['challengeId'] as int;
    final options = challenge['publicKeyOptions'] as Map<String, dynamic>;

    _log('Défi de signature $challengeId reçu');

    onStep?.call(SigningStep.confirming);
    final credential = await confirmWithPasskey(options);

    _log('Passkey confirmée pour la signature');

    onStep?.call(SigningStep.signing);
    final signature = await signingService.signDocument(preview.bytes);

    onStep?.call(SigningStep.submitting);
    final outcome = await repository.submitSignature(
      document.id,
      challengeId: challengeId,
      credential: credential,
      signature: signature,
    );

    _log('Signature acceptée par le serveur');

    return outcome;
  }

  void _log(String message) => session?.addLog(message);
}
