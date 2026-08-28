import 'dart:async';
import 'dart:io';

import 'package:credential_manager/credential_manager.dart';
import 'package:http/http.dart' as http;

import '../api.dart';

/// Turns whatever went wrong into something the person holding the phone can
/// act on.
///
/// Three very different sources land in the same catch block — the server's
/// error envelope, the Android credential manager, and the network stack —
/// and "Échec de la connexion." for all of them tells nobody what to do next.
String describeAuthError(Object error, {required bool enrolling}) {
  if (error is ApiException) {
    return _fromServer(error, enrolling: enrolling);
  }

  if (error is CredentialException) {
    return _fromCredentialManager(error, enrolling: enrolling);
  }

  if (error is SocketException ||
      error is http.ClientException ||
      error is HandshakeException) {
    return "Serveur injoignable. Vérifiez votre connexion et l'adresse du "
        'serveur dans les paramètres.';
  }

  if (error is TimeoutException) {
    return 'Le serveur met trop de temps à répondre. Réessayez.';
  }

  return enrolling
      ? "La création de la passkey a échoué : $error"
      : 'La connexion a échoué : $error';
}

String _fromServer(ApiException error, {required bool enrolling}) {
  switch (error.code) {
    case 'missing_username':
      return "Saisissez votre nom d'utilisateur.";

    case 'missing_password':
      return 'Saisissez le mot de passe de votre compte pour créer une passkey.';

    case 'invalid_credentials':
      return "Nom d'utilisateur ou mot de passe incorrect.";

    case 'no_passkey':
      return "Aucune passkey n'est associée à ce compte sur ce serveur. "
          'Créez-en une avec le mot de passe de votre compte.';

    case 'unknown_passkey':
      return "Cette passkey n'est pas reconnue par ce serveur. Elle a peut-être "
          'été créée sur un autre serveur : créez-en une nouvelle.';

    case 'no_ceremony':
      return enrolling
          ? 'La création de la passkey a expiré. Recommencez.'
          : 'La connexion a expiré. Réessayez.';

    case 'ceremony_mismatch':
      return 'La vérification ne correspond pas au compte saisi. Recommencez.';

    case 'passkey_rejected':
      return "Le serveur a refusé cette passkey. Vérifiez que l'application "
          'pointe bien vers le bon serveur.';

    case 'method_not_allowed':
    case 'invalid_json':
      return 'Le serveur a répondu de façon inattendue. Vérifiez son adresse '
          'dans les paramètres.';
  }

  // An unmapped code still carries the server's own sentence, which beats a
  // generic failure message.
  if (error.message.isNotEmpty) {
    return error.message;
  }

  return 'Le serveur a répondu ${error.statusCode}.';
}

String _fromCredentialManager(
  CredentialException error, {
  required bool enrolling,
}) {
  switch (error.code) {
    case 201:
    case 301:
    case 601:
      return enrolling
          ? 'Création de la passkey annulée.'
          : 'Connexion annulée.';

    case 202:
    case 603:
      return "Aucune passkey pour ce compte n'a été trouvée sur cet appareil. "
          'Créez-en une, ou utilisez le téléphone sur lequel elle a été créée.';

    case 205:
      return 'Trop de tentatives annulées. Android bloque temporairement les '
          'passkeys : réessayez dans quelques minutes.';

    case 209:
      return "Google Play Services est indisponible sur cet appareil, les "
          'passkeys ne peuvent pas fonctionner.';

    case 101:
      return "Le gestionnaire d'identifiants n'a pas pu démarrer. Redémarrez "
          "l'application.";

    case 302:
    case 602:
      return "L'appareil n'a pas pu créer la passkey. Vérifiez qu'un "
          'verrouillage d\'écran (code, empreinte) est configuré.';
  }

  return enrolling
      ? 'La création de la passkey a échoué (${error.code}) : ${error.message}'
      : 'La connexion par passkey a échoué (${error.code}) : ${error.message}';
}
