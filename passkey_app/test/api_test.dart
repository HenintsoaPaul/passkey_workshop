import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:passkey_app/api.dart';

void main() {
  group('Api', () {
    test('registerOptions posts the username and returns decoded options', () async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'challenge': 'abc123'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await http.runWithClient(
        () => Api.registerOptions('alice', 'secret'),
        () => mockClient,
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.url.path, '/chiffrement_app/register/options/');
      expect(jsonDecode(capturedRequest!.body), {
        'username': 'alice',
        'password': 'secret',
      });
      expect(result, {'challenge': 'abc123'});
    });

    test('registerVerify posts the username and credential', () async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'success': true, 'username': 'alice'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final credential = {'id': 'cred-1', 'rawId': 'cred-1'};

      final result = await http.runWithClient(
        () => Api.registerVerify('alice', credential),
        () => mockClient,
      );

      expect(capturedRequest!.url.path, '/chiffrement_app/register/verify/');
      expect(jsonDecode(capturedRequest!.body), {
        'username': 'alice',
        'credential': credential,
      });
      expect(result, {'success': true, 'username': 'alice'});
    });

    test('loginOptions posts the username', () async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'challenge': 'xyz789'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await http.runWithClient(
        () => Api.loginOptions('bob'),
        () => mockClient,
      );

      expect(capturedRequest!.url.path, '/chiffrement_app/login/options/');
      expect(jsonDecode(capturedRequest!.body), {'username': 'bob'});
      expect(result, {'challenge': 'xyz789'});
    });

    test('loginVerify posts the credential', () async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'success': true, 'username': 'bob'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final credential = {'rawId': 'cred-1'};

      final result = await http.runWithClient(
        () => Api.loginVerify(credential),
        () => mockClient,
      );

      expect(capturedRequest!.url.path, '/chiffrement_app/login/verify/');
      expect(jsonDecode(capturedRequest!.body), {'credential': credential});
      expect(result, {'success': true, 'username': 'bob'});
    });

    test('propagates the session cookie from a Set-Cookie response to the next request', () async {
      final requests = <http.Request>[];
      var callCount = 0;

      final mockClient = MockClient((request) async {
        requests.add(request);
        callCount++;

        final headers = callCount == 1
            ? {
                'content-type': 'application/json',
                'set-cookie': 'sessionid=abc123; Path=/; HttpOnly',
              }
            : {'content-type': 'application/json'};

        return http.Response(jsonEncode({'ok': true}), 200, headers: headers);
      });

      await http.runWithClient(() async {
        await Api.registerOptions('alice', 'secret');
        await Api.loginOptions('alice');
      }, () => mockClient);

      expect(requests, hasLength(2));
      expect(requests[1].headers['Cookie'], 'sessionid=abc123');
    });

    test('throws when the server responds with a non-2xx status', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'bad request'}), 400);
      });

      await http.runWithClient(() async {
        await expectLater(
          Api.registerOptions('alice', 'secret'),
          throwsA(isA<Exception>()),
        );
      }, () => mockClient);
    });
  });
}
