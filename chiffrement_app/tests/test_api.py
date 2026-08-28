"""Tests unitaires pour l'API JSON mobile, les clés RSA et le cycle de signature."""

import base64
import json
import shutil
import tempfile
from unittest.mock import Mock, patch

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa, utils
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from chiffrement_app.models import (
    Document,
    DocumentSigner,
    Passkey,
    Signature,
    SigningChallenge,
    SigningKey,
    UserProfile,
)
from chiffrement_app.services import create_document, recompute_document_status


MEDIA_ROOT = tempfile.mkdtemp(prefix='chiffrement-tests-')


def make_key_pair():
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    public_pem = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode()

    return private_key, public_pem


def sign_digest(private_key, digest_hex):
    """Produce what the phone produces: an RSA signature over the SHA-256 digest."""
    signature = private_key.sign(
        bytes.fromhex(digest_hex),
        padding.PKCS1v15(),
        utils.Prehashed(hashes.SHA256()),
    )

    return base64.b64encode(signature).decode()


@override_settings(MEDIA_ROOT=MEDIA_ROOT)
class ApiTestCase(TestCase):
    """Shared fixtures: a document, two signers, keys and passkeys."""

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(MEDIA_ROOT, ignore_errors=True)
        super().tearDownClass()

    def setUp(self):
        self.owner = User.objects.create_user(username='owner')
        self.alice = User.objects.create_user(username='alice')
        self.bob = User.objects.create_user(username='bob')
        self.mallory = User.objects.create_user(username='mallory')

        for user, name in [
            (self.owner, 'Olivier Owner'),
            (self.alice, 'Alice Martin'),
            (self.bob, 'Bob Dupont'),
            (self.mallory, 'Mallory Intruse'),
        ]:
            UserProfile.objects.create(user=user, name=name, email=f'{user.username}@x.fr')

        self.document = create_document(
            title='Contrat multi-signataires',
            description='Document de test',
            file=SimpleUploadedFile('contrat.txt', b'Contenu du contrat.', 'text/plain'),
            owner=self.owner,
        )

        DocumentSigner.objects.create(document=self.document, user=self.alice)
        DocumentSigner.objects.create(document=self.document, user=self.bob)
        recompute_document_status(self.document)
        self.document.refresh_from_db()

        self.alice_private, self.alice_public = make_key_pair()
        self.alice_key = SigningKey.objects.create(
            user=self.alice,
            public_key_pem=self.alice_public,
            algorithm='RSA-2048',
            fingerprint='a' * 64,
        )

        self.alice_passkey = Passkey.objects.create(
            user=self.alice,
            credential_id=b'alice-credential',
            public_key=b'alice-passkey-public',
            sign_count=1,
        )

    def post_json(self, url, payload):
        return self.client.post(
            url, data=json.dumps(payload), content_type='application/json'
        )

    def url(self, name, **kwargs):
        return reverse(f'api:{name}', kwargs=kwargs)

    def doc_url(self, name):
        return self.url(name, document_id=self.document.id)

    def raw_id(self, passkey):
        return base64.urlsafe_b64encode(bytes(passkey.credential_id)).decode().rstrip('=')


class AuthenticationTests(ApiTestCase):
    """Chaque endpoint refuse un appelant non authentifié."""

    def test_every_endpoint_requires_a_session(self):
        endpoints = [
            ('get', self.url('me')),
            ('get', self.url('signing_keys')),
            ('get', self.url('document_list')),
            ('get', self.doc_url('document_detail')),
            ('get', self.doc_url('document_file')),
            ('get', self.doc_url('document_verification')),
            ('post', self.doc_url('sign_challenge')),
            ('post', self.doc_url('sign_document')),
        ]

        for method, url in endpoints:
            with self.subTest(url=url):
                response = getattr(self.client, method)(url)
                self.assertEqual(response.status_code, 401)
                self.assertEqual(response.json()['error'], 'authentication_required')

    def test_wrong_method_is_rejected(self):
        self.client.force_login(self.alice)

        response = self.client.get(self.doc_url('sign_document'))

        self.assertEqual(response.status_code, 405)
        self.assertEqual(response.json()['error'], 'method_not_allowed')

    def test_me_reports_identity_and_key_state(self):
        self.client.force_login(self.alice)

        data = self.client.get(self.url('me')).json()

        self.assertEqual(data['username'], 'alice')
        self.assertEqual(data['name'], 'Alice Martin')
        self.assertTrue(data['hasSigningKey'])
        self.assertEqual(data['passkeyCount'], 1)


class SigningKeyTests(ApiTestCase):
    """Enregistrement de la clé publique RSA (la clé privée ne sort jamais)."""

    def test_registers_a_public_key(self):
        self.client.force_login(self.bob)
        _, public_pem = make_key_pair()

        response = self.post_json(self.url('signing_keys'), {'publicKeyPem': public_pem})

        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertTrue(data['created'])
        self.assertEqual(data['signingKey']['algorithm'], 'RSA-2048')
        self.assertEqual(len(data['signingKey']['fingerprint']), 64)

        key = SigningKey.objects.get(user=self.bob)
        self.assertNotIn('PRIVATE', key.public_key_pem)

    def test_rejects_a_private_key(self):
        self.client.force_login(self.bob)

        private_key, _ = make_key_pair()
        private_pem = private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        ).decode()

        response = self.post_json(self.url('signing_keys'), {'publicKeyPem': private_pem})

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'private_key_rejected')
        self.assertFalse(SigningKey.objects.filter(user=self.bob).exists())

    def test_rejects_a_key_that_is_too_small(self):
        self.client.force_login(self.bob)

        weak = rsa.generate_private_key(public_exponent=65537, key_size=1024)
        pem = weak.public_key().public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        ).decode()

        response = self.post_json(self.url('signing_keys'), {'publicKeyPem': pem})

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'invalid_public_key')

    def test_rejects_garbage(self):
        self.client.force_login(self.bob)

        response = self.post_json(self.url('signing_keys'), {'publicKeyPem': 'not a pem'})

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'invalid_public_key')

    def test_registering_again_revokes_the_previous_key(self):
        self.client.force_login(self.bob)

        _, first = make_key_pair()
        _, second = make_key_pair()

        self.post_json(self.url('signing_keys'), {'publicKeyPem': first})
        self.post_json(self.url('signing_keys'), {'publicKeyPem': second})

        keys = SigningKey.objects.filter(user=self.bob).order_by('created_at')
        self.assertEqual(keys.count(), 2)
        self.assertIsNotNone(keys[0].revoked_at)
        self.assertIsNone(keys[1].revoked_at)

    def test_same_key_twice_is_idempotent(self):
        self.client.force_login(self.bob)
        _, pem = make_key_pair()

        self.post_json(self.url('signing_keys'), {'publicKeyPem': pem})
        response = self.post_json(self.url('signing_keys'), {'publicKeyPem': pem})

        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.json()['created'])
        self.assertEqual(SigningKey.objects.filter(user=self.bob).count(), 1)


class DocumentAccessTests(ApiTestCase):
    """Un document n'est visible que par son propriétaire et ses signataires."""

    def test_signer_sees_the_document(self):
        self.client.force_login(self.alice)

        data = self.client.get(self.url('document_list')).json()

        self.assertEqual(len(data['documents']), 1)
        document = data['documents'][0]
        self.assertEqual(document['title'], 'Contrat multi-signataires')
        self.assertTrue(document['canSign'])
        self.assertFalse(document['hasSigned'])
        self.assertEqual(document['signerCount'], 2)

    def test_owner_sees_their_own_document(self):
        self.client.force_login(self.owner)

        data = self.client.get(self.url('document_list')).json()

        self.assertEqual(len(data['documents']), 1)
        self.assertFalse(data['documents'][0]['canSign'])

    def test_stranger_sees_nothing(self):
        self.client.force_login(self.mallory)

        self.assertEqual(self.client.get(self.url('document_list')).json()['documents'], [])
        self.assertEqual(self.client.get(self.doc_url('document_detail')).status_code, 404)
        self.assertEqual(self.client.get(self.doc_url('document_file')).status_code, 404)

    def test_detail_includes_signers_and_audit_trail(self):
        self.client.force_login(self.alice)

        data = self.client.get(self.doc_url('document_detail')).json()

        self.assertEqual(len(data['signers']), 2)
        self.assertEqual(data['fileHash'], self.document.file_hash)
        current = [s for s in data['signers'] if s['isCurrentUser']]
        self.assertEqual(len(current), 1)
        self.assertEqual(current[0]['name'], 'Alice Martin')
        self.assertIn('auditTrail', data)

    def test_file_download_carries_the_hash(self):
        self.client.force_login(self.alice)

        response = self.client.get(self.doc_url('document_file'))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(b''.join(response.streaming_content), b'Contenu du contrat.')
        self.assertEqual(response['X-Document-Hash'], self.document.file_hash)


@patch('chiffrement_app.api.verify_authentication_response')
class SigningFlowTests(ApiTestCase):
    """Défi passkey par signature, puis vérification RSA côté serveur."""

    def request_challenge(self, user=None):
        return self.post_json(
            self.doc_url('sign_challenge'),
            {'documentHash': self.document.file_hash},
        )

    def sign_as_alice(self, mock_verify, digest=None, signature=None):
        mock_verify.return_value = Mock(new_sign_count=2)

        challenge = self.request_challenge().json()

        return self.post_json(
            self.doc_url('sign_document'),
            {
                'challengeId': challenge['challengeId'],
                'credential': {'rawId': self.raw_id(self.alice_passkey)},
                'signature': signature
                or sign_digest(
                    self.alice_private, digest or challenge['documentHash']
                ),
            },
        )

    def test_challenge_is_bound_to_the_document_and_expires(self, mock_verify):
        self.client.force_login(self.alice)

        response = self.request_challenge()

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data['documentHash'], self.document.file_hash)
        self.assertIn('challenge', data['publicKeyOptions'])

        challenge = SigningChallenge.objects.get(id=data['challengeId'])
        self.assertEqual(challenge.user, self.alice)
        self.assertEqual(challenge.document, self.document)
        self.assertEqual(challenge.document_hash, self.document.file_hash)
        self.assertTrue(challenge.is_usable())

    def test_challenge_rejects_a_stale_client_hash(self, mock_verify):
        self.client.force_login(self.alice)

        response = self.post_json(self.doc_url('sign_challenge'), {'documentHash': 'b' * 64})

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'hash_mismatch')
        self.assertFalse(SigningChallenge.objects.exists())

    def test_challenge_requires_a_registered_key(self, mock_verify):
        self.client.force_login(self.bob)

        response = self.request_challenge()

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'no_signing_key')

    def test_challenge_refuses_a_non_signer(self, mock_verify):
        self.client.force_login(self.owner)

        response = self.request_challenge()

        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()['error'], 'not_a_signer')

    def test_signature_is_recorded_and_moves_the_document_forward(self, mock_verify):
        self.client.force_login(self.alice)

        response = self.sign_as_alice(mock_verify)

        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data['document']['status'], 'partially_signed')
        self.assertTrue(data['document']['hasSigned'])
        self.assertFalse(data['document']['canSign'])
        self.assertEqual(data['verification']['verdict'], 'incomplete')

        signature = Signature.objects.get(document=self.document, signer=self.alice)
        self.assertEqual(signature.document_hash, self.document.file_hash)
        self.assertEqual(signature.signing_key, self.alice_key)

        signer = DocumentSigner.objects.get(document=self.document, user=self.alice)
        self.assertEqual(signer.signature_status, 'signed')

        self.document.refresh_from_db()
        self.assertEqual(self.document.status, 'partially_signed')

    def test_passkey_sign_count_is_updated(self, mock_verify):
        self.client.force_login(self.alice)

        self.sign_as_alice(mock_verify)

        self.alice_passkey.refresh_from_db()
        self.assertEqual(self.alice_passkey.sign_count, 2)

    def test_a_tampered_signature_is_refused(self, mock_verify):
        self.client.force_login(self.alice)

        other_private, _ = make_key_pair()
        forged = sign_digest(other_private, self.document.file_hash)

        response = self.sign_as_alice(mock_verify, signature=forged)

        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()['error'], 'invalid_signature')
        self.assertFalse(Signature.objects.exists())

        self.document.refresh_from_db()
        self.assertEqual(self.document.status, 'pending')

    def test_a_signature_over_another_digest_is_refused(self, mock_verify):
        self.client.force_login(self.alice)

        response = self.sign_as_alice(mock_verify, digest='c' * 64)

        self.assertEqual(response.status_code, 422)
        self.assertFalse(Signature.objects.exists())

    def test_a_failed_passkey_confirmation_blocks_the_signature(self, mock_verify):
        self.client.force_login(self.alice)
        mock_verify.side_effect = ValueError('user verification missing')

        challenge = self.request_challenge().json()

        response = self.post_json(
            self.doc_url('sign_document'),
            {
                'challengeId': challenge['challengeId'],
                'credential': {'rawId': self.raw_id(self.alice_passkey)},
                'signature': sign_digest(self.alice_private, challenge['documentHash']),
            },
        )

        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()['error'], 'passkey_verification_failed')
        self.assertFalse(Signature.objects.exists())

        # The challenge is burnt even on failure, so a rejected attempt cannot
        # be retried against the same nonce.
        self.assertFalse(
            SigningChallenge.objects.get(id=challenge['challengeId']).is_usable()
        )

    def test_a_challenge_cannot_be_replayed(self, mock_verify):
        self.client.force_login(self.alice)
        mock_verify.return_value = Mock(new_sign_count=2)

        challenge = self.request_challenge().json()
        payload = {
            'challengeId': challenge['challengeId'],
            'credential': {'rawId': self.raw_id(self.alice_passkey)},
            'signature': sign_digest(self.alice_private, challenge['documentHash']),
        }

        first = self.post_json(self.doc_url('sign_document'), payload)
        self.assertEqual(first.status_code, 201)

        Signature.objects.all().delete()

        second = self.post_json(self.doc_url('sign_document'), payload)
        self.assertEqual(second.status_code, 400)
        self.assertEqual(second.json()['error'], 'challenge_expired')

    def test_an_expired_challenge_is_refused(self, mock_verify):
        self.client.force_login(self.alice)
        mock_verify.return_value = Mock(new_sign_count=2)

        challenge_data = self.request_challenge().json()

        challenge = SigningChallenge.objects.get(id=challenge_data['challengeId'])
        challenge.expires_at = timezone.now() - timezone.timedelta(seconds=1)
        challenge.save(update_fields=['expires_at'])

        response = self.post_json(
            self.doc_url('sign_document'),
            {
                'challengeId': challenge.id,
                'credential': {'rawId': self.raw_id(self.alice_passkey)},
                'signature': sign_digest(self.alice_private, challenge.document_hash),
            },
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'challenge_expired')

    def test_another_users_challenge_cannot_be_used(self, mock_verify):
        self.client.force_login(self.alice)
        challenge = self.request_challenge().json()

        _, bob_public = make_key_pair()
        SigningKey.objects.create(
            user=self.bob, public_key_pem=bob_public, fingerprint='b' * 64
        )
        Passkey.objects.create(
            user=self.bob, credential_id=b'bob-credential', public_key=b'bob-pk'
        )

        self.client.force_login(self.bob)

        response = self.post_json(
            self.doc_url('sign_document'),
            {
                'challengeId': challenge['challengeId'],
                'credential': {'rawId': self.raw_id(self.alice_passkey)},
                'signature': sign_digest(self.alice_private, challenge['documentHash']),
            },
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'unknown_challenge')

    def test_signing_twice_is_refused(self, mock_verify):
        self.client.force_login(self.alice)

        self.sign_as_alice(mock_verify)

        # Refused as early as the challenge, so a second ceremony never even
        # prompts the user.
        challenge = self.request_challenge()
        self.assertEqual(challenge.status_code, 409)
        self.assertEqual(challenge.json()['error'], 'already_signed')

        # And refused again at the signing endpoint, for a client that skipped
        # straight to it with a stale challenge id.
        response = self.post_json(
            self.doc_url('sign_document'),
            {
                'challengeId': 1,
                'credential': {'rawId': self.raw_id(self.alice_passkey)},
                'signature': sign_digest(self.alice_private, self.document.file_hash),
            },
        )

        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()['error'], 'already_signed')
        self.assertEqual(Signature.objects.count(), 1)

    def test_document_is_fully_signed_once_everyone_has_signed(self, mock_verify):
        bob_private, bob_public = make_key_pair()
        SigningKey.objects.create(
            user=self.bob, public_key_pem=bob_public, fingerprint='b' * 64
        )
        bob_passkey = Passkey.objects.create(
            user=self.bob, credential_id=b'bob-credential', public_key=b'bob-pk'
        )

        self.client.force_login(self.alice)
        self.sign_as_alice(mock_verify)

        self.client.force_login(self.bob)
        mock_verify.return_value = Mock(new_sign_count=3)
        challenge = self.request_challenge().json()

        response = self.post_json(
            self.doc_url('sign_document'),
            {
                'challengeId': challenge['challengeId'],
                'credential': {'rawId': self.raw_id(bob_passkey)},
                'signature': sign_digest(bob_private, challenge['documentHash']),
            },
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data['document']['status'], 'fully_signed')
        self.assertEqual(data['verification']['verdict'], 'valid')

        # Both signers covered the very same bytes.
        hashes_signed = set(Signature.objects.values_list('document_hash', flat=True))
        self.assertEqual(len(hashes_signed), 1)


@patch('chiffrement_app.api.verify_authentication_response')
class VerificationTests(ApiTestCase):
    """Vérification globale : §2.5."""

    def sign_everyone(self, mock_verify):
        mock_verify.return_value = Mock(new_sign_count=2)

        bob_private, bob_public = make_key_pair()
        SigningKey.objects.create(
            user=self.bob, public_key_pem=bob_public, fingerprint='b' * 64
        )
        bob_passkey = Passkey.objects.create(
            user=self.bob, credential_id=b'bob-credential', public_key=b'bob-pk'
        )

        for user, private_key, passkey in [
            (self.alice, self.alice_private, self.alice_passkey),
            (self.bob, bob_private, bob_passkey),
        ]:
            self.client.force_login(user)
            challenge = self.post_json(
                self.doc_url('sign_challenge'),
                {'documentHash': self.document.file_hash},
            ).json()

            self.post_json(
                self.doc_url('sign_document'),
                {
                    'challengeId': challenge['challengeId'],
                    'credential': {
                        'rawId': base64.urlsafe_b64encode(bytes(passkey.credential_id))
                        .decode()
                        .rstrip('=')
                    },
                    'signature': sign_digest(private_key, challenge['documentHash']),
                },
            )

    def test_unsigned_document_is_incomplete_not_invalid(self, mock_verify):
        self.client.force_login(self.alice)

        data = self.client.get(self.doc_url('document_verification')).json()

        self.assertEqual(data['verdict'], 'incomplete')
        self.assertEqual(data['signedCount'], 0)
        self.assertEqual(data['requiredCount'], 2)
        self.assertEqual(sorted(data['missingSigners']), ['Alice Martin', 'Bob Dupont'])

    def test_fully_signed_document_passes_all_four_checks(self, mock_verify):
        self.sign_everyone(mock_verify)

        self.client.force_login(self.alice)
        data = self.client.get(self.doc_url('document_verification')).json()

        self.assertEqual(data['verdict'], 'valid')
        self.assertEqual(data['currentHash'], data['storedHash'])
        self.assertEqual(len(data['checks']), 4)
        self.assertTrue(all(check['passed'] for check in data['checks']))
        self.assertTrue(all(s['isValid'] for s in data['signatures']))

    def test_modifying_the_file_invalidates_the_document(self, mock_verify):
        self.sign_everyone(mock_verify)

        # Overwrite the bytes behind the document's back: exactly the tampering
        # the digest comparison exists to catch.
        with open(self.document.file.path, 'wb') as handle:
            handle.write(b'Contenu modifie apres signature.')

        self.client.force_login(self.alice)
        data = self.client.get(self.doc_url('document_verification')).json()

        self.assertEqual(data['verdict'], 'invalid')
        self.assertNotEqual(data['currentHash'], data['storedHash'])

        checks = {check['code']: check for check in data['checks']}
        self.assertFalse(checks['hash_matches']['passed'])
        # The signatures themselves are still mathematically sound; it is the
        # document that no longer matches them.
        self.assertTrue(checks['signatures_valid']['passed'])

    def test_a_revoked_key_invalidates_its_signature(self, mock_verify):
        self.sign_everyone(mock_verify)

        self.alice_key.revoked_at = timezone.now()
        self.alice_key.save(update_fields=['revoked_at'])

        self.client.force_login(self.alice)
        data = self.client.get(self.doc_url('document_verification')).json()

        self.assertEqual(data['verdict'], 'invalid')
        alice_report = [s for s in data['signatures'] if s['signer'] == 'alice'][0]
        self.assertFalse(alice_report['isValid'])
        self.assertIn('révoquée', alice_report['reason'])
