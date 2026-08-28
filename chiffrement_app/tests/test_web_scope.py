"""Tests unitaires du périmètre de l'application web (§1).

« Les documents signés et les signatures électroniques doivent être visibles
uniquement dans l'application mobile. » Le web crée les comptes, dépose les
documents, affecte les signataires, suit l'état et vérifie — mais il ne sert
ni le fichier ni les valeurs de signature.
"""

import base64
import shutil
import tempfile

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa, utils
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse

from chiffrement_app.models import (
    Document,
    DocumentSigner,
    Signature,
    SigningKey,
    UserProfile,
)
from chiffrement_app.services import create_document

from .base import DEFAULT_PASSWORD


MEDIA_ROOT = tempfile.mkdtemp(prefix='chiffrement-web-')


@override_settings(MEDIA_ROOT=MEDIA_ROOT)
class WebScopeTestCase(TestCase):

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(MEDIA_ROOT, ignore_errors=True)
        super().tearDownClass()

    def setUp(self):
        self.owner = User.objects.create_user(username='owner', password=DEFAULT_PASSWORD)
        self.alice = User.objects.create_user(username='alice', password=DEFAULT_PASSWORD)
        self.admin = User.objects.create_user(
            username='admin', password=DEFAULT_PASSWORD, is_staff=True
        )

        for user, name in [
            (self.owner, 'Olivier Owner'),
            (self.alice, 'Alice Martin'),
            (self.admin, 'Adele Admin'),
        ]:
            UserProfile.objects.create(user=user, name=name, email=f'{user.username}@x.fr')

        self.document = create_document(
            title='Contrat web',
            file=SimpleUploadedFile('c.txt', b'Contenu du contrat.', 'text/plain'),
            owner=self.owner,
        )
        DocumentSigner.objects.create(document=self.document, user=self.alice)

    def record_signature(self):
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        public_pem = private_key.public_key().public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        ).decode()

        key = SigningKey.objects.create(
            user=self.alice, public_key_pem=public_pem, fingerprint='a' * 64
        )

        digest = self.document.file_hash
        raw = private_key.sign(
            bytes.fromhex(digest), padding.PKCS1v15(), utils.Prehashed(hashes.SHA256())
        )

        return Signature.objects.create(
            document=self.document,
            document_version=self.document.current_version,
            signer=self.alice,
            signing_key=key,
            document_hash=digest,
            signature_value=base64.b64encode(raw).decode(),
        )


class SignedContentStaysMobileOnlyTests(WebScopeTestCase):

    def test_the_detail_page_does_not_link_to_the_file(self):
        self.client.login(username='owner', password=DEFAULT_PASSWORD)

        response = self.client.get(
            reverse('chiffrement_app:document_detail', kwargs={'document_id': self.document.id})
        )
        body = response.content.decode()

        self.assertEqual(response.status_code, 200)
        self.assertNotIn(self.document.file.url, body)
        self.assertNotIn('.txt" class', body)

    def test_no_web_route_serves_the_document_file(self):
        """MEDIA_URL is deliberately not wired into urlpatterns."""
        self.client.login(username='owner', password=DEFAULT_PASSWORD)

        response = self.client.get(self.document.file.url)

        self.assertEqual(response.status_code, 404)

    def test_the_verification_page_never_exposes_a_signature_value(self):
        signature = self.record_signature()
        self.client.login(username='owner', password=DEFAULT_PASSWORD)

        response = self.client.get(
            reverse('chiffrement_app:verify_document', kwargs={'document_id': self.document.id})
        )
        body = response.content.decode()

        self.assertEqual(response.status_code, 200)
        # The verdict and the signer are web business; the signature itself is not.
        self.assertNotIn(signature.signature_value, body)
        self.assertIn('Alice Martin', body)

    def test_a_stranger_cannot_open_the_document(self):
        stranger = User.objects.create_user(username='mallory', password=DEFAULT_PASSWORD)
        UserProfile.objects.create(user=stranger, name='Mallory', email='m@x.fr')

        self.client.login(username='mallory', password=DEFAULT_PASSWORD)
        response = self.client.get(
            reverse('chiffrement_app:document_detail', kwargs={'document_id': self.document.id})
        )

        self.assertRedirects(response, reverse('chiffrement_app:dashboard'))


class UserAdministrationTests(WebScopeTestCase):

    def test_an_administrator_can_create_a_signatory(self):
        self.client.login(username='admin', password=DEFAULT_PASSWORD)

        response = self.client.post(reverse('chiffrement_app:user_create'), {
            'username': 'bob',
            'name': 'Bob Dupont',
            'email': 'bob@x.fr',
            'password': 'un-mot-de-passe',
        })

        bob = User.objects.get(username='bob')
        self.assertRedirects(
            response, reverse('chiffrement_app:user_detail', kwargs={'user_id': bob.id})
        )
        self.assertEqual(bob.profile.name, 'Bob Dupont')
        self.assertTrue(bob.check_password('un-mot-de-passe'))

    def test_a_non_administrator_cannot(self):
        self.client.login(username='owner', password=DEFAULT_PASSWORD)

        response = self.client.post(reverse('chiffrement_app:user_create'), {
            'username': 'bob',
            'password': 'un-mot-de-passe',
        })

        self.assertRedirects(response, reverse('chiffrement_app:user_list'))
        self.assertFalse(User.objects.filter(username='bob').exists())

    def test_a_duplicate_username_is_refused(self):
        self.client.login(username='admin', password=DEFAULT_PASSWORD)

        response = self.client.post(reverse('chiffrement_app:user_create'), {
            'username': 'alice',
            'password': 'un-mot-de-passe',
        })

        self.assertEqual(response.status_code, 200)
        self.assertEqual(User.objects.filter(username='alice').count(), 1)

    def test_a_short_password_is_refused(self):
        self.client.login(username='admin', password=DEFAULT_PASSWORD)

        self.client.post(reverse('chiffrement_app:user_create'), {
            'username': 'bob',
            'password': 'court',
        })

        self.assertFalse(User.objects.filter(username='bob').exists())

    def test_the_user_page_shows_public_keys_and_never_private_ones(self):
        self.record_signature()
        self.client.login(username='admin', password=DEFAULT_PASSWORD)

        response = self.client.get(
            reverse('chiffrement_app:user_detail', kwargs={'user_id': self.alice.id})
        )
        body = response.content.decode()

        self.assertEqual(response.status_code, 200)
        self.assertIn('a' * 64, body)
        self.assertNotIn('PRIVATE KEY', body)
        self.assertNotIn('BEGIN PUBLIC KEY', body)


class VersionUploadTests(WebScopeTestCase):

    def version_url(self):
        return reverse(
            'chiffrement_app:upload_version', kwargs={'document_id': self.document.id}
        )

    def test_the_owner_can_deposit_a_new_version(self):
        self.record_signature()
        self.client.login(username='owner', password=DEFAULT_PASSWORD)

        response = self.client.post(self.version_url(), {
            'file': SimpleUploadedFile('c2.txt', b'Contenu revise.', 'text/plain'),
        })

        self.assertRedirects(
            response,
            reverse('chiffrement_app:document_detail', kwargs={'document_id': self.document.id}),
        )

        self.document.refresh_from_db()
        self.assertEqual(self.document.versions.count(), 2)
        self.assertEqual(self.document.version_number, 2)
        self.assertEqual(self.document.status, 'pending')

    def test_a_signer_who_is_not_the_owner_cannot(self):
        self.client.login(username='alice', password=DEFAULT_PASSWORD)

        response = self.client.post(self.version_url(), {
            'file': SimpleUploadedFile('c2.txt', b'Contenu revise.', 'text/plain'),
        })

        self.assertEqual(response.status_code, 404)
        self.assertEqual(self.document.versions.count(), 1)

    def test_a_missing_file_is_refused(self):
        self.client.login(username='owner', password=DEFAULT_PASSWORD)

        self.client.post(self.version_url(), {})

        self.assertEqual(self.document.versions.count(), 1)
