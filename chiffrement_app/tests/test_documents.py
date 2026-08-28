from django.test import TestCase, Client
from django.urls import reverse
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile

from chiffrement_app.models import Document
from .base import DEFAULT_PASSWORD


class DocumentUploadTests(TestCase):
    """Tests unitaires pour le téléversement de documents."""

    def setUp(self):
        self.client = Client()
        self.upload_url = reverse('chiffrement_app:upload_document')
        self.login_url = reverse('chiffrement_app:login')
        self.dashboard_url = reverse('chiffrement_app:dashboard')

        self.user = User.objects.create_user(
            username='uploader',
            email='uploader@example.com',
            password=DEFAULT_PASSWORD
        )

    def test_upload_page_requires_login(self):
        response = self.client.get(self.upload_url)
        self.assertRedirects(response, f"{self.login_url}?next={self.upload_url}")

    def test_upload_document_success(self):
        self.client.login(username='uploader', password=DEFAULT_PASSWORD)
        file_content = b"Contenu de test pour la signature electronique."
        uploaded_file = SimpleUploadedFile("contrat_test.pdf", file_content, content_type="application/pdf")

        data = {
            'title': 'Contrat Unique Test',
            'description': 'Description du contrat de test',
            'file': uploaded_file
        }
        response = self.client.post(self.upload_url, data)
        doc = Document.objects.get(title='Contrat Unique Test')
        self.assertRedirects(response, reverse('chiffrement_app:document_detail', kwargs={'document_id': doc.id}))
        self.assertTrue(Document.objects.filter(title='Contrat Unique Test', owner=self.user).exists())

    def test_upload_document_title_unicity(self):
        self.client.login(username='uploader', password=DEFAULT_PASSWORD)
        initial_file = SimpleUploadedFile("existant.pdf", b"Initial file content", content_type="application/pdf")
        Document.objects.create(
            title='Document Existant',
            file=initial_file,
            owner=self.user
        )
        file_content = b"Autre contenu"
        uploaded_file = SimpleUploadedFile("autre.pdf", file_content, content_type="application/pdf")
        data = {
            'title': 'Document Existant',
            'file': uploaded_file
        }
        response = self.client.post(self.upload_url, data)
        self.assertEqual(response.status_code, 200)
        self.assertIn('error', response.context)
