from django.test import TestCase, Client
from django.urls import reverse
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from chiffrement_app.models import UserProfile, Document, SignatureLog


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
        self.assertRedirects(response, self.dashboard_url)
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
