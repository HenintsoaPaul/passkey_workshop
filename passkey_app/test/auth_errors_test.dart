import 'dart:async';
import 'dart:io';

import 'package:credential_manager/credential_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:passkey_app/api.dart';
import 'package:passkey_app/utils/auth_errors.dart';

ApiException server(String code, {String detail = '', int status = 400}) {
  return ApiException(statusCode: status, code: code, message: detail);
}

CredentialException device(int code, [String message = 'x']) {
  return CredentialException(code: code, message: message, details: null);
}

void main() {
  group('server errors', () {
    test('bad credentials name the two things that could be wrong', () {
      final message = describeAuthError(
        server('invalid_credentials', status: 401),
        enrolling: true,
      );

      expect(message, "Nom d'utilisateur ou mot de passe incorrect.");
    });

    test('no passkey tells the user how to get one', () {
      final message = describeAuthError(
        server('no_passkey', status: 404),
        enrolling: false,
      );

      expect(message, contains('Aucune passkey'));
      expect(message, contains('Créez-en une'));
    });

    test('an expired ceremony reads differently for each action', () {
      expect(
        describeAuthError(server('no_ceremony'), enrolling: true),
        contains('création de la passkey a expiré'),
      );
      expect(
        describeAuthError(server('no_ceremony'), enrolling: false),
        contains('connexion a expiré'),
      );
    });

    test('a passkey from another server says so', () {
      final message = describeAuthError(
        server('unknown_passkey', status: 401),
        enrolling: false,
      );

      expect(message, contains('autre serveur'));
    });

    test('an unmapped code falls back to the server sentence', () {
      final message = describeAuthError(
        server('something_new', detail: 'Le quota est dépassé.'),
        enrolling: false,
      );

      expect(message, 'Le quota est dépassé.');
    });

    test('an unmapped code with no detail still says something', () {
      final message = describeAuthError(
        server('something_new', status: 503),
        enrolling: false,
      );

      expect(message, contains('503'));
    });
  });

  group('device errors', () {
    test('every cancellation code reads as a cancellation', () {
      for (final code in [201, 301, 601]) {
        expect(
          describeAuthError(device(code), enrolling: false),
          'Connexion annulée.',
          reason: '$code',
        );
        expect(
          describeAuthError(device(code), enrolling: true),
          'Création de la passkey annulée.',
          reason: '$code',
        );
      }
    });

    test('no credential on this device suggests the right phone', () {
      final message = describeAuthError(device(202), enrolling: false);

      expect(message, contains('cet appareil'));
      expect(message, contains('téléphone sur lequel elle a été créée'));
    });

    test('a temporary Android block explains the wait', () {
      expect(
        describeAuthError(device(205), enrolling: false),
        contains('quelques minutes'),
      );
    });

    test('a missing screen lock is named as the likely cause', () {
      expect(
        describeAuthError(device(602), enrolling: true),
        contains('verrouillage'),
      );
    });

    test('an unmapped device code keeps the code and message', () {
      final message = describeAuthError(device(999, 'boom'), enrolling: false);

      expect(message, contains('999'));
      expect(message, contains('boom'));
    });
  });

  group('transport errors', () {
    test('a dead socket points at the server address', () {
      final message = describeAuthError(
        const SocketException('failed'),
        enrolling: false,
      );

      expect(message, contains('Serveur injoignable'));
      expect(message, contains('paramètres'));
    });

    test('an http client failure reads the same way', () {
      expect(
        describeAuthError(http.ClientException('boom'), enrolling: false),
        contains('Serveur injoignable'),
      );
    });

    test('a timeout says to retry', () {
      expect(
        describeAuthError(TimeoutException('slow'), enrolling: false),
        contains('Réessayez'),
      );
    });

    test('an unknown object still produces a sentence, not a crash', () {
      expect(
        describeAuthError('bizarre', enrolling: true),
        contains('bizarre'),
      );
    });
  });
}
