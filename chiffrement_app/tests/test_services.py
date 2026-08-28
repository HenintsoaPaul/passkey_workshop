"""Tests unitaires de la couche services : état global et vérification (§2.5).

Logique pure, sans HTTP : `recompute_document_status` et `verify_document`
sont la source unique de vérité partagée par l'API et les vues web, donc ils
sont testés directement.
"""

import base64
import shutil
import tempfile

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa, utils
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone

from chiffrement_app.models import (
    Document,
    DocumentSigner,
    Signature,
    SigningKey,
    UserProfile,
)
from chiffrement_app.services import (
    current_document_hash,
    mark_signer_signed,
    recompute_document_status,
    verify_document,
)


MEDIA_ROOT = tempfile.mkdtemp(prefix='chiffrement-services-')


@override_settings(MEDIA_ROOT=MEDIA_ROOT)
class ServiceTestCase(TestCase):

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(MEDIA_ROOT, ignore_errors=True)
        super().tearDownClass()

    def setUp(self):
        self.owner = User.objects.create_user(username='owner')
        self.alice = User.objects.create_user(username='alice')
        self.bob = User.objects.create_user(username='bob')

        for user, name in [
            (self.owner, 'Olivier Owner'),
            (self.alice, 'Alice Martin'),
            (self.bob, 'Bob Dupont'),
        ]:
            UserProfile.objects.create(user=user, name=name, email=f'{user.username}@x.fr')

        self.document = Document.objects.create(
            title='Contrat de services',
            file=SimpleUploadedFile('c.txt', b'Contenu du contrat.', 'text/plain'),
            owner=self.owner,
            status='pending',
        )

        self.keys = {}

    def add_signer(self, user):
        return DocumentSigner.objects.create(document=self.document, user=user)

    def sign(self, user, document_hash=None, tamper=False):
        """Record a genuine RSA signature for `user`."""
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        public_pem = private_key.public_key().public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        ).decode()

        key = SigningKey.objects.create(
            user=user, public_key_pem=public_pem, fingerprint=f'{user.username:0<64}'
        )
        self.keys[user.username] = key

        digest = document_hash or self.document.file_hash

        if tamper:
            # Sign a different digest than the one recorded, which is what a
            # forged or mismatched signature looks like.
            signed = 'f' * 64
        else:
            signed = digest

        signature = private_key.sign(
            bytes.fromhex(signed),
            padding.PKCS1v15(),
            utils.Prehashed(hashes.SHA256()),
        )

        return Signature.objects.create(
            document=self.document,
            signer=user,
            signing_key=key,
            document_hash=digest,
            signature_value=base64.b64encode(signature).decode(),
        )


class RecomputeStatusTests(ServiceTestCase):

    def test_a_document_without_signers_is_a_draft(self):
        self.assertEqual(recompute_document_status(self.document), 'draft')

    def test_assigned_but_unsigned_is_pending(self):
        self.add_signer(self.alice)
        self.add_signer(self.bob)

        self.assertEqual(recompute_document_status(self.document), 'pending')

    def test_one_signature_of_two_is_partially_signed(self):
        self.add_signer(self.alice)
        self.add_signer(self.bob)
        self.sign(self.alice)

        self.assertEqual(recompute_document_status(self.document), 'partially_signed')

    def test_every_signature_present_is_fully_signed(self):
        self.add_signer(self.alice)
        self.add_signer(self.bob)
        self.sign(self.alice)
        self.sign(self.bob)

        self.assertEqual(recompute_document_status(self.document), 'fully_signed')

    def test_the_status_is_persisted(self):
        self.add_signer(self.alice)
        self.sign(self.alice)

        recompute_document_status(self.document)
        self.document.refresh_from_db()

        self.assertEqual(self.document.status, 'fully_signed')

    def test_an_archived_document_is_left_alone(self):
        self.add_signer(self.alice)
        self.document.status = 'archived'
        self.document.save()

        self.assertEqual(recompute_document_status(self.document), 'archived')

    def test_removing_a_signature_walks_the_status_back(self):
        self.add_signer(self.alice)
        self.add_signer(self.bob)
        self.sign(self.alice)
        self.sign(self.bob)
        self.assertEqual(recompute_document_status(self.document), 'fully_signed')

        Signature.objects.filter(signer=self.bob).delete()

        self.assertEqual(recompute_document_status(self.document), 'partially_signed')

    def test_recomputing_does_not_rehash_the_file(self):
        """`Document.save()` re-reads the whole file; the status path must not."""
        self.add_signer(self.alice)
        self.sign(self.alice)
        recompute_document_status(self.document)

        # Corrupt the stored hash, recompute, and confirm it was not silently
        # recalculated behind our back.
        Document.objects.filter(pk=self.document.pk).update(file_hash='0' * 64)
        self.document.refresh_from_db()
        recompute_document_status(self.document)
        self.document.refresh_from_db()

        self.assertEqual(self.document.file_hash, '0' * 64)


class MarkSignerSignedTests(ServiceTestCase):

    def test_marks_the_row_and_writes_a_log(self):
        self.add_signer(self.alice)

        signer = mark_signer_signed(self.document, self.alice)

        self.assertEqual(signer.signature_status, 'signed')
        self.assertIsNotNone(signer.signature_date)
        self.assertTrue(
            self.document.logs.filter(action='signed', user=self.alice).exists()
        )

    def test_returns_none_for_someone_who_is_not_a_signer(self):
        self.assertIsNone(mark_signer_signed(self.document, self.bob))


class VerifyDocumentTests(ServiceTestCase):

    def test_unsigned_document_is_incomplete_and_names_who_is_missing(self):
        self.add_signer(self.alice)
        self.add_signer(self.bob)

        report = verify_document(self.document)

        self.assertEqual(report['verdict'], 'incomplete')
        self.assertEqual(sorted(report['missing_signers']), ['Alice Martin', 'Bob Dupont'])
        self.assertEqual(report['signed_count'], 0)
        self.assertEqual(report['required_count'], 2)

    def test_all_four_conditions_pass_for_a_fully_signed_document(self):
        self.add_signer(self.alice)
        self.add_signer(self.bob)
        self.sign(self.alice)
        self.sign(self.bob)

        report = verify_document(self.document)

        self.assertEqual(report['verdict'], 'valid')
        codes = {c['code'] for c in report['checks']}
        self.assertEqual(
            codes,
            {'signatures_present', 'signatures_valid', 'same_version', 'hash_matches'},
        )
        self.assertTrue(all(c['passed'] for c in report['checks']))

    def test_a_partially_signed_document_is_incomplete_not_invalid(self):
        self.add_signer(self.alice)
        self.add_signer(self.bob)
        self.sign(self.alice)

        report = verify_document(self.document)

        self.assertEqual(report['verdict'], 'incomplete')
        self.assertEqual(report['missing_signers'], ['Bob Dupont'])
        # The signature that does exist is still cryptographically sound.
        self.assertTrue(report['signatures'][0]['is_valid'])

    def test_a_forged_signature_makes_the_document_invalid(self):
        self.add_signer(self.alice)
        self.sign(self.alice, tamper=True)

        report = verify_document(self.document)

        self.assertEqual(report['verdict'], 'invalid')
        checks = {c['code']: c for c in report['checks']}
        self.assertFalse(checks['signatures_valid']['passed'])

    def test_modifying_the_file_breaks_only_the_hash_condition(self):
        self.add_signer(self.alice)
        self.sign(self.alice)

        with open(self.document.file.path, 'wb') as handle:
            handle.write(b'Contenu modifie apres signature.')

        report = verify_document(self.document)

        self.assertEqual(report['verdict'], 'invalid')
        checks = {c['code']: c for c in report['checks']}
        self.assertFalse(checks['hash_matches']['passed'])
        # The signature itself is untouched; it is the document that moved.
        self.assertTrue(checks['signatures_valid']['passed'])
        self.assertNotEqual(report['current_hash'], report['stored_hash'])

    def test_signatures_over_different_versions_fail_the_same_version_check(self):
        self.add_signer(self.alice)
        self.add_signer(self.bob)
        self.sign(self.alice)
        self.sign(self.bob, document_hash='a' * 64)

        report = verify_document(self.document)

        checks = {c['code']: c for c in report['checks']}
        self.assertFalse(checks['same_version']['passed'])
        self.assertEqual(report['verdict'], 'invalid')

    def test_a_revoked_key_invalidates_its_signature(self):
        self.add_signer(self.alice)
        self.sign(self.alice)

        key = self.keys['alice']
        key.revoked_at = timezone.now()
        key.save(update_fields=['revoked_at'])

        report = verify_document(self.document)

        self.assertEqual(report['verdict'], 'invalid')
        self.assertFalse(report['signatures'][0]['is_valid'])
        self.assertIn('révoquée', report['signatures'][0]['reason'])

    def test_an_unreadable_file_is_reported_rather_than_crashing(self):
        self.add_signer(self.alice)
        self.sign(self.alice)

        import os
        os.remove(self.document.file.path)

        report = verify_document(self.document)

        self.assertIsNone(report['current_hash'])
        self.assertEqual(report['verdict'], 'invalid')

    def test_current_document_hash_reads_the_bytes_on_disk(self):
        self.assertEqual(current_document_hash(self.document), self.document.file_hash)

        with open(self.document.file.path, 'wb') as handle:
            handle.write(b'autre chose')

        self.assertNotEqual(current_document_hash(self.document), self.document.file_hash)
