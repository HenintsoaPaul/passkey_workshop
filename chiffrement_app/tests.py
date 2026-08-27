from django.test import TestCase, Client
from django.urls import reverse
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from chiffrement_app.models import UserProfile, Document, DocumentSigner, SignatureLog


class AuthenticationTests(TestCase):
    """Tests unitaires pour l'inscription, la connexion et la déconnexion."""

    def setUp(self):
        self.client = Client()
        self.register_url = reverse('chiffrement_app:register')
        self.login_url = reverse('chiffrement_app:login')
        self.logout_url = reverse('chiffrement_app:logout')
        self.dashboard_url = reverse('chiffrement_app:dashboard')

        self.existing_user = User.objects.create_user(
            username='existinguser',
            email='existing@example.com',
            password='Password123!'
        )
        self.existing_profile = UserProfile.objects.create(
            user=self.existing_user,
            name='Existing User',
            email='existing@example.com',
            phone='0340000000',
            address='Rue 1',
            city='Antananarivo'
        )

    def test_register_page_loads(self):
        response = self.client.get(self.register_url)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'register.html')

    def test_register_success(self):
        data = {
            'username': 'newuser',
            'email': 'newuser@example.com',
            'password': 'StrongPassword123!',
            'password_confirm': 'StrongPassword123!',
            'name': 'New User',
            'phone': '0341234567',
            'address': 'Lot II A',
            'city': 'Antananarivo'
        }
        response = self.client.post(self.register_url, data)
        self.assertRedirects(response, self.login_url)
        self.assertTrue(User.objects.filter(username='newuser').exists())

    def test_register_password_mismatch(self):
        data = {
            'username': 'mismatchuser',
            'email': 'mismatch@example.com',
            'password': 'Password123!',
            'password_confirm': 'Different123!',
            'name': 'Mismatch User'
        }
        response = self.client.post(self.register_url, data)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'register.html')
        self.assertIn('error', response.context)

    def test_login_page_loads_when_unauthenticated(self):
        response = self.client.get(self.login_url)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'login.html')

    def test_login_success(self):
        data = {
            'username': 'existinguser',
            'password': 'Password123!'
        }
        response = self.client.post(self.login_url, data)
        self.assertRedirects(response, self.dashboard_url)

    def test_logout(self):
        self.client.login(username='existinguser', password='Password123!')
        response = self.client.get(self.logout_url)
        self.assertRedirects(response, self.login_url)


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
            password='Password123!'
        )

    def test_upload_page_requires_login(self):
        response = self.client.get(self.upload_url)
        self.assertRedirects(response, f"{self.login_url}?next={self.upload_url}")

    def test_upload_document_success(self):
        self.client.login(username='uploader', password='Password123!')
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
        self.client.login(username='uploader', password='Password123!')
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


class UserManagementTests(TestCase):
    """Tests unitaires pour la gestion des utilisateurs et des profils."""

    def setUp(self):
        self.client = Client()
        self.profile_url = reverse('chiffrement_app:profile')
        self.profile_edit_url = reverse('chiffrement_app:profile_edit')
        self.user_list_url = reverse('chiffrement_app:user_list')

        self.user = User.objects.create_user(
            username='johndoe',
            email='john@example.com',
            password='Password123!'
        )
        self.profile = UserProfile.objects.create(
            user=self.user,
            name='John Doe',
            email='john@example.com',
            organization='CyberCorp',
            job_title='Security Engineer'
        )

    def test_profile_view_authenticated(self):
        self.client.login(username='johndoe', password='Password123!')
        response = self.client.get(self.profile_url)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'users/profile.html')
        self.assertContains(response, 'CyberCorp')
        self.assertContains(response, 'Security Engineer')

    def test_profile_edit_success(self):
        self.client.login(username='johndoe', password='Password123!')
        data = {
            'name': 'Johnathan Doe',
            'email': 'johnathan@example.com',
            'organization': 'SecureTech',
            'job_title': 'Lead Analyst',
            'bio': 'Passionate about cyber security and cryptography.'
        }
        response = self.client.post(self.profile_edit_url, data)
        self.assertRedirects(response, self.profile_url)

        self.profile.refresh_from_db()
        self.assertEqual(self.profile.organization, 'SecureTech')
        self.assertEqual(self.profile.job_title, 'Lead Analyst')
        self.assertEqual(self.profile.bio, 'Passionate about cyber security and cryptography.')

    def test_user_list_and_search(self):
        self.client.login(username='johndoe', password='Password123!')
        response = self.client.get(self.user_list_url)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'users/list.html')
        self.assertContains(response, 'johndoe')

        # Test de recherche
        response_search = self.client.get(f"{self.user_list_url}?q=CyberCorp")
        self.assertContains(response_search, 'johndoe')

        response_empty = self.client.get(f"{self.user_list_url}?q=NonExistentCorp")
        self.assertContains(response_empty, 'Aucun utilisateur trouvé.')

    def test_user_detail_view(self):
        self.client.login(username='johndoe', password='Password123!')
        user_detail_url = reverse('chiffrement_app:user_detail', kwargs={'user_id': self.user.id})
        response = self.client.get(user_detail_url)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'users/detail.html')
        self.assertContains(response, 'John Doe')


class SignatureWorkflowTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(username='doc_owner', password='Password123!')
        self.signer1 = User.objects.create_user(username='signer1', password='Password123!')
        self.signer2 = User.objects.create_user(username='signer2', password='Password123!')

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
        self.client.login(username='doc_owner', password='Password123!')
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
        self.client.login(username='signer1', password='Password123!')
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
        self.client.login(username='signer2', password='Password123!')
        resp_sign2 = self.client.post(sign_url)
        self.assertRedirects(resp_sign2, detail_url)

        self.doc.refresh_from_db()
        self.assertEqual(self.doc.status, 'fully_signed')

    def test_verify_document_integrity(self):
        self.client.login(username='doc_owner', password='Password123!')
        verify_url = reverse('chiffrement_app:verify_document', kwargs={'document_id': self.doc.id})
        response = self.client.get(verify_url)

        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'documents/verify.html')
        self.assertTrue(response.context['is_valid'])
        self.assertEqual(response.context['current_hash'], self.doc.file_hash)

    def test_archive_document(self):
        self.client.login(username='doc_owner', password='Password123!')
        archive_url = reverse('chiffrement_app:archive_document', kwargs={'document_id': self.doc.id})
        response = self.client.get(archive_url)

        self.assertRedirects(response, reverse('chiffrement_app:document_detail', kwargs={'document_id': self.doc.id}))
        self.doc.refresh_from_db()
        self.assertEqual(self.doc.status, 'archived')

