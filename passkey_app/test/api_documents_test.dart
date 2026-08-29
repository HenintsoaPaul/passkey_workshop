import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:passkey_app/api.dart';

http.Response json(Object body, [int status = 200]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  setUp(() {
    Api.clearSession();
    Api.onUnauthenticated = null;
  });

  group('document endpoints', () {
    test('fetchDocuments unwraps the documents list', () async {
      http.Request? captured;

      final client = MockClient((request) async {
        captured = request;
        return json({
          'documents': [
            {'id': '1', 'title': 'Contrat'},
          ],
        });
      });

      final documents = await http.runWithClient(
        Api.fetchDocuments,
        () => client,
      );

      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/api/documents/');
      expect(documents, hasLength(1));
    });

    test('downloadDocument returns the raw bytes', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/documents/7/file/');
        return http.Response.bytes([1, 2, 3, 4], 200);
      });

      final bytes = await http.runWithClient(
        () => Api.downloadDocument('7'),
        () => client,
      );

      expect(bytes, [1, 2, 3, 4]);
    });

    test('fetchVerification hits the verify route', () async {
      http.Request? captured;

      final client = MockClient((request) async {
        captured = request;
        return json({'verdict': 'valid'});
      });

      await http.runWithClient(
        () => Api.fetchVerification('7'),
        () => client,
      );

      expect(captured!.url.path, '/api/documents/7/verify/');
    });
  });

  group('signing endpoints', () {
    test('registerSigningKey posts only the public PEM', () async {
      http.Request? captured;

      final client = MockClient((request) async {
        captured = request;
        return json({
          'signingKey': {'fingerprint': 'abc'},
          'created': true,
        }, 201);
      });

      await http.runWithClient(
        () => Api.registerSigningKey('-----BEGIN PUBLIC KEY-----\nAAA\n---'),
        () => client,
      );

      expect(captured!.url.path, '/api/keys/');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body.keys, ['publicKeyPem']);
      expect(body['publicKeyPem'], isNot(contains('PRIVATE')));
    });

    test('signChallenge sends the locally computed hash', () async {
      http.Request? captured;

      final client = MockClient((request) async {
        captured = request;
        return json({'challengeId': 1, 'publicKeyOptions': {}});
      });

      await http.runWithClient(
        () => Api.signChallenge('7', 'a' * 64),
        () => client,
      );

      expect(captured!.url.path, '/api/documents/7/sign/challenge/');
      expect(jsonDecode(captured!.body), {'documentHash': 'a' * 64});
    });

    test('submitSignature sends the challenge, credential and signature',
        () async {
      http.Request? captured;

      final client = MockClient((request) async {
        captured = request;
        return json({'signature': {}, 'document': {}, 'verification': {}}, 201);
      });

      await http.runWithClient(
        () => Api.submitSignature(
          '7',
          challengeId: 42,
          credential: {'rawId': 'cred'},
          signature: 'c2ln',
        ),
        () => client,
      );

      expect(captured!.url.path, '/api/documents/7/sign/');
      expect(jsonDecode(captured!.body), {
        'challengeId': 42,
        'credential': {'rawId': 'cred'},
        'signature': 'c2ln',
      });
    });
  });

  group('errors', () {
    test('turns the server error envelope into an ApiException', () async {
      final client = MockClient((request) async {
        return json({
          'error': 'already_signed',
          'detail': 'Vous avez déjà signé ce document.',
        }, 409);
      });

      await http.runWithClient(() async {
        try {
          await Api.fetchDocument('7');
          fail('expected an ApiException');
        } on ApiException catch (error) {
          expect(error.statusCode, 409);
          expect(error.code, 'already_signed');
          expect(error.message, 'Vous avez déjà signé ce document.');
          expect(error.isUnauthenticated, isFalse);
        }
      }, () => client);
    });

    test('flags a 401 so the app knows to sign in again', () async {
      final client = MockClient((request) async {
        return json({'error': 'authentication_required'}, 401);
      });

      await http.runWithClient(() async {
        try {
          await Api.me();
          fail('expected an ApiException');
        } on ApiException catch (error) {
          expect(error.isUnauthenticated, isTrue);
        }
      }, () => client);
    });

    test('a 401 clears the cookies and notifies the app once', () async {
      var signedOut = 0;
      Api.onUnauthenticated = () => signedOut++;

      final requests = <http.BaseRequest>[];
      var call = 0;

      final client = MockClient((request) async {
        requests.add(request);
        call++;

        if (call == 1) {
          return http.Response(
            jsonEncode({'ok': true}),
            200,
            headers: {
              'content-type': 'application/json',
              'set-cookie': 'sessionid=stale; Path=/',
            },
          );
        }

        return json({'error': 'authentication_required'}, 401);
      });

      await http.runWithClient(() async {
        await Api.loginVerify({'rawId': 'cred'});
        await expectLater(Api.me(), throwsA(isA<ApiException>()));
        await expectLater(Api.me(), throwsA(isA<ApiException>()));
      }, () => client);

      expect(signedOut, 2);
      // The stale cookie must not be replayed after the server rejected it.
      expect(requests.last.headers.containsKey('Cookie'), isFalse);
    });

    test('survives a non-JSON error body', () async {
      final client = MockClient((request) async {
        return http.Response('<html>502 Bad Gateway</html>', 502);
      });

      await http.runWithClient(() async {
        try {
          await Api.me();
          fail('expected an ApiException');
        } on ApiException catch (error) {
          expect(error.statusCode, 502);
          expect(error.code, 'http_error');
        }
      }, () => client);
    });
  });

  group('session cookies', () {
    // Verbatim from Django: signing in rotates the CSRF token as well as the
    // session, and package:http collapses both Set-Cookie headers into one
    // comma-separated string whose expires= attributes contain commas of
    // their own. Taking the first ';'-delimited chunk of that string yields
    // the CSRF token and silently loses the session.
    const djangoLoginSetCookie =
        'csrftoken=qoDTARWUp020jkUXdwCvD3H7VIm3rhZp; '
        'expires=Fri, 27 Aug 2027 21:19:28 GMT; Max-Age=31449600; Path=/; '
        'SameSite=Lax, '
        'sessionid=3bzverw9yvp5osvsvqq5wyltoljukzjr; '
        'expires=Fri, 11 Sep 2026 21:19:28 GMT; HttpOnly; Max-Age=1209600; '
        'Path=/; SameSite=Lax';

    test('keeps the session id when the server sets several cookies at once',
        () async {
      final requests = <http.BaseRequest>[];
      var call = 0;

      final client = MockClient((request) async {
        requests.add(request);
        call++;

        return http.Response(
          jsonEncode({'documents': <Object>[]}),
          200,
          headers: call == 1
              ? {
                  'content-type': 'application/json',
                  'set-cookie': djangoLoginSetCookie,
                }
              : {'content-type': 'application/json'},
        );
      });

      await http.runWithClient(() async {
        await Api.loginVerify({'rawId': 'cred'});
        await Api.fetchDocuments();
      }, () => client);

      final cookie = requests[1].headers['Cookie']!;

      expect(cookie, contains('sessionid=3bzverw9yvp5osvsvqq5wyltoljukzjr'));
      expect(cookie, contains('csrftoken=qoDTARWUp020jkUXdwCvD3H7VIm3rhZp'));
      expect(cookie, isNot(contains('expires')));
      expect(cookie, isNot(contains('SameSite')));
    });

    test('a later response updates only the cookie it re-sets', () async {
      final requests = <http.BaseRequest>[];
      var call = 0;

      final client = MockClient((request) async {
        requests.add(request);
        call++;

        return http.Response(
          jsonEncode({'documents': <Object>[]}),
          200,
          headers: {
            'content-type': 'application/json',
            if (call == 1) 'set-cookie': djangoLoginSetCookie,
            if (call == 2)
              'set-cookie': 'sessionid=rotated; Path=/; HttpOnly',
          },
        );
      });

      await http.runWithClient(() async {
        await Api.loginVerify({'rawId': 'cred'});
        await Api.fetchDocuments();
        await Api.me();
      }, () => client);

      final cookie = requests[2].headers['Cookie']!;

      expect(cookie, contains('sessionid=rotated'));
      expect(cookie, contains('csrftoken=qoDTARWUp020jkUXdwCvD3H7VIm3rhZp'));
    });
  });

  group('session', () {
    test('sends the captured cookie on later requests', () async {
      final requests = <http.BaseRequest>[];
      var call = 0;

      final client = MockClient((request) async {
        requests.add(request);
        call++;

        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: call == 1
              ? {
                  'content-type': 'application/json',
                  'set-cookie': 'sessionid=zzz; Path=/; HttpOnly',
                }
              : {'content-type': 'application/json'},
        );
      });

      await http.runWithClient(() async {
        await Api.loginOptions('alice');
        await Api.me();
      }, () => client);

      expect(requests[1].headers['Cookie'], 'sessionid=zzz');
    });

    test('clearSession drops the cookie', () async {
      final requests = <http.BaseRequest>[];

      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {
            'content-type': 'application/json',
            'set-cookie': 'sessionid=zzz; Path=/',
          },
        );
      });

      await http.runWithClient(() async {
        await Api.loginOptions('alice');
        Api.clearSession();
        await Api.me();
      }, () => client);

      expect(requests[1].headers.containsKey('Cookie'), isFalse);
    });
  });
}
