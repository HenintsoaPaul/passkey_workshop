import base64
import json
from unittest.mock import Mock, patch

from django.contrib.auth.models import User
from django.test import TestCase
from django.urls import reverse

from chiffrement_app.models import Passkey


class AssetlinksTests(TestCase):
    """Tests unitaires pour l'endpoint Digital Asset Links (.well-known/assetlinks.json)."""

    def test_assetlinks_returns_expected_structure(self):
        response = self.client.get('/.well-known/assetlinks.json')

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data[0]['target']['namespace'], 'android_app')
        self.assertIn('delegate_permission/common.get_login_creds', data[0]['relation'])


class PasskeyRegistrationTests(TestCase):
    """Tests unitaires pour l'inscription d'une passkey (register/options, register/verify)."""

    def setUp(self):
        self.options_url = reverse('chiffrement_app:passkey_register_options')
        self.verify_url = reverse('chiffrement_app:passkey_register_verify')

    def post_json(self, url, payload):
        return self.client.post(url, data=json.dumps(payload), content_type='application/json')

    def test_register_options_requires_post(self):
        response = self.client.get(self.options_url)
        self.assertEqual(response.status_code, 405)

    def test_register_options_requires_the_account_password(self):
        """Enrôler une passkey exige de prouver son identité.

        Sans cela, connaître un nom d'utilisateur suffisait pour rattacher sa
        propre passkey au compte de quelqu'un d'autre.
        """
        User.objects.create_user(username='alice', password='bon-mot-de-passe')

        response = self.post_json(self.options_url, {'username': 'alice'})

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'missing_password')
        self.assertNotIn('registration_challenge', self.client.session)

    def test_register_options_refuses_a_wrong_password(self):
        User.objects.create_user(username='alice', password='bon-mot-de-passe')

        response = self.post_json(self.options_url, {
            'username': 'alice',
            'password': 'mauvais',
        })

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()['error'], 'invalid_credentials')

    def test_register_options_no_longer_creates_accounts(self):
        response = self.post_json(self.options_url, {
            'username': 'inconnu',
            'password': 'peu-importe',
        })

        self.assertEqual(response.status_code, 401)
        self.assertFalse(User.objects.filter(username='inconnu').exists())

    def test_an_unknown_user_is_indistinguishable_from_a_wrong_password(self):
        """Le message ne doit pas révéler quels comptes existent."""
        User.objects.create_user(username='alice', password='bon-mot-de-passe')

        unknown = self.post_json(self.options_url, {
            'username': 'inconnu', 'password': 'x',
        })
        wrong = self.post_json(self.options_url, {
            'username': 'alice', 'password': 'x',
        })

        self.assertEqual(unknown.json(), wrong.json())
        self.assertEqual(unknown.status_code, wrong.status_code)

    def test_register_options_stores_the_challenge_for_a_valid_account(self):
        User.objects.create_user(username='alice', password='bon-mot-de-passe')

        response = self.post_json(self.options_url, {
            'username': 'alice',
            'password': 'bon-mot-de-passe',
        })

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn('challenge', data)
        self.assertEqual(data['user']['name'], 'alice')
        self.assertIn('registration_challenge', self.client.session)
        self.assertEqual(self.client.session['registration_user'], User.objects.get(username='alice').id)

    def test_register_verify_requires_post(self):
        response = self.client.get(self.verify_url)
        self.assertEqual(response.status_code, 405)

    def test_register_verify_rejects_without_prior_ceremony(self):
        User.objects.create_user(username='alice')

        session = self.client.session
        session['registration_challenge'] = ''
        session.save()

        response = self.post_json(self.verify_url, {
            'username': 'alice',
            'credential': {},
        })

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'no_ceremony')

    @patch('chiffrement_app.views.verify_registration_response')
    def test_register_verify_refuses_a_different_account(self, mock_verify):
        """La cérémonie doit se terminer pour le compte qui l'a commencée."""
        User.objects.create_user(username='alice', password='bon-mot-de-passe')
        User.objects.create_user(username='mallory', password='autre')

        self.post_json(self.options_url, {
            'username': 'alice', 'password': 'bon-mot-de-passe',
        })

        response = self.post_json(self.verify_url, {
            'username': 'mallory',
            'credential': {'id': 'x'},
        })

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'ceremony_mismatch')
        self.assertFalse(Passkey.objects.exists())

    def test_register_verify_reports_a_rejected_passkey(self):
        User.objects.create_user(username='alice', password='bon-mot-de-passe')

        self.post_json(self.options_url, {
            'username': 'alice', 'password': 'bon-mot-de-passe',
        })

        # A credential the library cannot verify must be a 400 with an
        # explanation, not a 500.
        response = self.post_json(self.verify_url, {
            'username': 'alice',
            'credential': {'id': 'pas-une-vraie-passkey'},
        })

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'passkey_rejected')

    @patch('chiffrement_app.views.verify_registration_response')
    def test_register_verify_creates_passkey(self, mock_verify):
        mock_verify.return_value = Mock(
            credential_id=b'credential-id-bytes',
            credential_public_key=b'public-key-bytes',
            sign_count=0,
        )

        User.objects.create_user(username='alice', password='bon-mot-de-passe')

        self.post_json(self.options_url, {
            'username': 'alice', 'password': 'bon-mot-de-passe',
        })

        response = self.post_json(self.verify_url, {
            'username': 'alice',
            'credential': {'id': 'fake-credential'},
        })

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data['success'])
        self.assertEqual(data['username'], 'alice')

        passkey = Passkey.objects.get(user__username='alice')
        self.assertEqual(bytes(passkey.credential_id), b'credential-id-bytes')
        self.assertEqual(bytes(passkey.public_key), b'public-key-bytes')
        self.assertEqual(passkey.sign_count, 0)

        self.assertNotIn('registration_challenge', self.client.session)
        self.assertNotIn('registration_user', self.client.session)


class PasskeyLoginTests(TestCase):
    """Tests unitaires pour la connexion par passkey (login/options, login/verify)."""

    def setUp(self):
        self.options_url = reverse('chiffrement_app:passkey_login_options')
        self.verify_url = reverse('chiffrement_app:passkey_login_verify')

        self.user = User.objects.create_user(username='bob')
        self.passkey = Passkey.objects.create(
            user=self.user,
            credential_id=b'cred-xyz',
            public_key=b'pub-xyz',
            sign_count=5,
        )

    def post_json(self, url, payload):
        return self.client.post(url, data=json.dumps(payload), content_type='application/json')

    def test_login_options_requires_post(self):
        response = self.client.get(self.options_url)
        self.assertEqual(response.status_code, 405)

    def test_login_options_lists_existing_passkeys(self):
        response = self.post_json(self.options_url, {'username': 'bob'})

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data['allowCredentials']), 1)
        self.assertEqual(self.client.session['authentication_user'], self.user.id)
        self.assertIn('authentication_challenge', self.client.session)

    def test_login_options_explains_when_no_passkey_exists(self):
        User.objects.create_user(username='sans_passkey')

        response = self.post_json(self.options_url, {'username': 'sans_passkey'})

        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()['error'], 'no_passkey')
        self.assertIn('Créez-en une', response.json()['detail'])

    def test_login_options_gives_the_same_answer_for_an_unknown_account(self):
        """Ne pas révéler quels comptes existent, tout en restant actionnable."""
        User.objects.create_user(username='sans_passkey')

        no_passkey = self.post_json(self.options_url, {'username': 'sans_passkey'})
        unknown = self.post_json(self.options_url, {'username': 'inexistant'})

        self.assertEqual(no_passkey.json(), unknown.json())
        self.assertEqual(no_passkey.status_code, unknown.status_code)

    def test_login_options_requires_a_username(self):
        response = self.post_json(self.options_url, {})

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'missing_username')

    def test_login_verify_reports_an_unknown_passkey(self):
        self.post_json(self.options_url, {'username': 'bob'})

        other = base64.urlsafe_b64encode(b'pas-la-bonne').decode().rstrip('=')
        response = self.post_json(self.verify_url, {'credential': {'rawId': other}})

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()['error'], 'unknown_passkey')

    def test_login_verify_reports_a_rejected_assertion_without_crashing(self):
        self.post_json(self.options_url, {'username': 'bob'})

        raw_id = base64.urlsafe_b64encode(b'cred-xyz').decode().rstrip('=')
        response = self.post_json(self.verify_url, {'credential': {'rawId': raw_id}})

        # The real library refuses this made-up assertion; it must surface as a
        # 401 the app can explain, not a 500.
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()['error'], 'passkey_rejected')

    def test_login_verify_requires_post(self):
        response = self.client.get(self.verify_url)
        self.assertEqual(response.status_code, 405)

    def test_login_verify_rejects_without_prior_ceremony(self):
        session = self.client.session
        session['authentication_challenge'] = ''
        session.save()

        response = self.post_json(self.verify_url, {'credential': {'rawId': 'anything'}})

        self.assertEqual(response.status_code, 400)
        self.assertIn('error', response.json())

    @patch('chiffrement_app.views.verify_authentication_response')
    def test_login_verify_updates_sign_count(self, mock_verify):
        mock_verify.return_value = Mock(new_sign_count=6)

        self.post_json(self.options_url, {'username': 'bob'})

        raw_id = base64.urlsafe_b64encode(b'cred-xyz').decode().rstrip('=')
        response = self.post_json(self.verify_url, {'credential': {'rawId': raw_id}})

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data['success'])
        self.assertEqual(data['username'], 'bob')

        self.passkey.refresh_from_db()
        self.assertEqual(self.passkey.sign_count, 6)

        self.assertNotIn('authentication_challenge', self.client.session)
        self.assertNotIn('authentication_user', self.client.session)

    @patch('chiffrement_app.views.verify_authentication_response')
    def test_login_verify_opens_a_session_for_the_api(self, mock_verify):
        """La connexion par passkey doit ouvrir une vraie session Django.

        Sans cela le client mobile repart avec un cookie de session anonyme et
        chaque appel à /api/ répond 401.
        """
        mock_verify.return_value = Mock(new_sign_count=6)

        self.post_json(self.options_url, {'username': 'bob'})

        raw_id = base64.urlsafe_b64encode(b'cred-xyz').decode().rstrip('=')
        self.post_json(self.verify_url, {'credential': {'rawId': raw_id}})

        self.assertEqual(int(self.client.session['_auth_user_id']), self.user.id)

        response = self.client.get(reverse('api:me'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['username'], 'bob')
