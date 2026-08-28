from django.test import TestCase
from django.urls import reverse
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile

from chiffrement_app.models import UserProfile, Document, DocumentSigner, SignatureLog
from .base import DEFAULT_PASSWORD


class SignatureWorkflowTests(TestCase):
    """Tests unitaires pour l'affectation des signataires et le cycle de signature."""

    def setUp(self):
        self.owner = User.objects.create_user(username='doc_owner', password=DEFAULT_PASSWORD)
        self.signer1 = User.objects.create_user(username='signer1', password=DEFAULT_PASSWORD)
        self.signer2 = User.objects.create_user(username='signer2', password=DEFAULT_PASSWORD)

        UserProfile.objects.create(user=self.owner, name='Doc Owner')
        UserProfile.objects.create(user=self.signer1, name='Signer One')
        UserProfile.objects.create(user=self.signer2, name='Signer Two')

        self.uploaded_file = SimpleUploadedFile(
            "contract.txt",
            b"Contrat de confidentialite et signature multiple.",
            content_type="text/plain"
        )
        self.doc = Document.objects.create(
            title="Contrat Confidentiel 2026",
            description="Document de test multi-signataires",
            file=self.uploaded_file,
            owner=self.owner,
            status='draft'
        )

    def test_assign_multiple_signers_and_logging(self):
        self.client.login(username='doc_owner', password=DEFAULT_PASSWORD)
        assign_url = reverse('chiffrement_app:assign_signers', kwargs={'document_id': self.doc.id})

        data = {'signers': [self.signer1.id, self.signer2.id]}
        response = self.client.post(assign_url, data)
        self.assertRedirects(response, reverse('chiffrement_app:document_detail', kwargs={'document_id': self.doc.id}))

        self.doc.refresh_from_db()
        self.assertEqual(self.doc.status, 'pending')
        self.assertEqual(self.doc.signers.count(), 2)

        # Check logs
        logs = SignatureLog.objects.filter(document=self.doc)
        self.assertTrue(logs.filter(details__contains='signer1').exists())
        self.assertTrue(logs.filter(details__contains='signer2').exists())

    def test_signer_workflow_and_status_progression(self):
        # Assign signers
        DocumentSigner.objects.create(document=self.doc, user=self.signer1, signature_status='pending')
        DocumentSigner.objects.create(document=self.doc, user=self.signer2, signature_status='pending')
        self.doc.status = 'pending'
        self.doc.save()

        # Signer 1 views document
        self.client.login(username='signer1', password=DEFAULT_PASSWORD)
        detail_url = reverse('chiffrement_app:document_detail', kwargs={'document_id': self.doc.id})
        resp_view = self.client.get(detail_url)
        self.assertEqual(resp_view.status_code, 200)

        s1_ds = DocumentSigner.objects.get(document=self.doc, user=self.signer1)
        self.assertEqual(s1_ds.signature_status, 'viewed')

        # Signer 1 signs document
        sign_url = reverse('chiffrement_app:sign_document', kwargs={'document_id': self.doc.id})
        resp_sign1 = self.client.post(sign_url)
        self.assertRedirects(resp_sign1, detail_url)

        self.doc.refresh_from_db()
        self.assertEqual(self.doc.status, 'partially_signed')

        # Signer 2 signs document
        self.client.login(username='signer2', password=DEFAULT_PASSWORD)
        resp_sign2 = self.client.post(sign_url)
        self.assertRedirects(resp_sign2, detail_url)

        self.doc.refresh_from_db()
        self.assertEqual(self.doc.status, 'fully_signed')

    def test_verify_document_integrity(self):
        self.client.login(username='doc_owner', password=DEFAULT_PASSWORD)
        verify_url = reverse('chiffrement_app:verify_document', kwargs={'document_id': self.doc.id})
        response = self.client.get(verify_url)

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'documents/verify.html')
        self.assertTrue(response.context['is_valid'])
        self.assertEqual(response.context['current_hash'], self.doc.file_hash)

    def test_archive_document(self):
        self.client.login(username='doc_owner', password=DEFAULT_PASSWORD)
        archive_url = reverse('chiffrement_app:archive_document', kwargs={'document_id': self.doc.id})
        response = self.client.get(archive_url)

        self.assertRedirects(response, reverse('chiffrement_app:document_detail', kwargs={'document_id': self.doc.id}))
        self.doc.refresh_from_db()
        self.assertEqual(self.doc.status, 'archived')
