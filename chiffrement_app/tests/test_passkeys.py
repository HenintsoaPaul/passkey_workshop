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

    def test_register_options_creates_user_and_stores_challenge(self):
        response = self.post_json(self.options_url, {'username': 'alice'})

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn('challenge', data)
        self.assertEqual(data['user']['name'], 'alice')
        self.assertTrue(User.objects.filter(username='alice').exists())
        self.assertIn('registration_challenge', self.client.session)

    def test_register_options_reuses_existing_user(self):
        self.post_json(self.options_url, {'username': 'alice'})
        self.post_json(self.options_url, {'username': 'alice'})

        self.assertEqual(User.objects.filter(username='alice').count(), 1)

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
        self.assertIn('error', response.json())

    @patch('chiffrement_app.views.verify_registration_response')
    def test_register_verify_creates_passkey(self, mock_verify):
        mock_verify.return_value = Mock(
            credential_id=b'credential-id-bytes',
            credential_public_key=b'public-key-bytes',
            sign_count=0,
        )

        self.post_json(self.options_url, {'username': 'alice'})

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
