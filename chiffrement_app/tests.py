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

        # Création d'un utilisateur existant pour les tests de doublons et de connexion
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

    # ==================== TESTS DE REGISTER ====================

    def test_register_page_loads(self):
        """Vérifie que la page d'inscription s'affiche correctement (GET)."""
        response = self.client.get(self.register_url)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'register.html')

    def test_register_success(self):
        """Vérifie la création réussie d'un nouvel utilisateur (POST)."""
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

        # Vérifier la redirection vers la page de connexion
        self.assertRedirects(response, self.login_url)

        # Vérifier que l'utilisateur et son profil existent en BDD
        self.assertTrue(User.objects.filter(username='newuser').exists())
        new_user = User.objects.get(username='newuser')
        self.assertEqual(new_user.email, 'newuser@example.com')
        self.assertTrue(UserProfile.objects.filter(user=new_user).exists())

    def test_register_password_mismatch(self):
        """Vérifie le rejet lorsque les mots de passe ne correspondent pas."""
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
        self.assertEqual(response.context['error'], 'Les mots de passe ne correspondent pas')
        self.assertFalse(User.objects.filter(username='mismatchuser').exists())

    def test_register_username_exists(self):
        """Vérifie l'erreur lorsqu'un nom d'utilisateur est déjà pris."""
        data = {
            'username': 'existinguser',
            'email': 'unique@example.com',
            'password': 'Password123!',
            'password_confirm': 'Password123!',
            'name': 'Duplicate User'
        }
        response = self.client.post(self.register_url, data)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'register.html')
        self.assertIn('error', response.context)
        self.assertEqual(response.context['error'], "Le nom d'utilisateur existe déjà")

    def test_register_email_exists(self):
        """Vérifie l'erreur lorsqu'une adresse email est déjà utilisée."""
        data = {
            'username': 'anotheruser',
            'email': 'existing@example.com',
            'password': 'Password123!',
            'password_confirm': 'Password123!',
            'name': 'Duplicate Email User'
        }
        response = self.client.post(self.register_url, data)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'register.html')
        self.assertIn('error', response.context)
        self.assertEqual(response.context['error'], "L'email existe déjà")

    # ==================== TESTS DE LOGIN ====================

    def test_login_page_loads_when_unauthenticated(self):
        """Vérifie que la page de connexion s'affiche pour un utilisateur non connecté."""
        response = self.client.get(self.login_url)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'login.html')

    def test_login_redirects_when_already_authenticated(self):
        """Vérifie la redirection vers le dashboard si l'utilisateur est déjà connecté."""
        self.client.login(username='existinguser', password='Password123!')
        response = self.client.get(self.login_url)
        self.assertRedirects(response, self.dashboard_url)

    def test_login_success(self):
        """Vérifie la connexion réussie avec des identifiants valides."""
        data = {
            'username': 'existinguser',
            'password': 'Password123!'
        }
        response = self.client.post(self.login_url, data)
        self.assertRedirects(response, self.dashboard_url)

        # Vérifier que l'utilisateur est bien connecté dans la session
        self.assertEqual(int(self.client.session['_auth_user_id']), self.existing_user.pk)

    def test_login_invalid_password(self):
        """Vérifie le rejet en cas de mot de passe incorrect."""
        data = {
            'username': 'existinguser',
            'password': 'WrongPassword'
        }
        response = self.client.post(self.login_url, data)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'login.html')
        self.assertIn('error', response.context)
        self.assertEqual(response.context['error'], "Nom d'utilisateur ou mot de passe incorrect")

    def test_login_nonexistent_user(self):
        """Vérifie le rejet en cas d'utilisateur inexistant."""
        data = {
            'username': 'unknownuser',
            'password': 'Password123!'
        }
        response = self.client.post(self.login_url, data)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'login.html')
        self.assertIn('error', response.context)
        self.assertEqual(response.context['error'], "Nom d'utilisateur ou mot de passe incorrect")

    # ==================== TESTS DE LOGOUT ====================

    def test_logout(self):
        """Vérifie la déconnexion d'un utilisateur connecté."""
        self.client.login(username='existinguser', password='Password123!')
        response = self.client.get(self.logout_url)
        self.assertRedirects(response, self.login_url)

        # Vérifier que la session ne contient plus l'utilisateur connecté
        self.assertNotIn('_auth_user_id', self.client.session)


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
        """Vérifie qu'un utilisateur non connecté est redirigé vers la connexion."""
        response = self.client.get(self.upload_url)
        self.assertRedirects(response, f"{self.login_url}?next={self.upload_url}")

    def test_upload_page_loads_when_authenticated(self):
        """Vérifie que la page de téléversement s'affiche pour un utilisateur connecté."""
        self.client.login(username='uploader', password='Password123!')
        response = self.client.get(self.upload_url)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'documents/upload.html')

    def test_upload_document_success(self):
        """Vérifie le téléversement réussi d'un fichier avec création du modèle et du log."""
        self.client.login(username='uploader', password='Password123!')
        
        file_content = b"Contenu de test pour la signature electronique."
        uploaded_file = SimpleUploadedFile("contrat_test.pdf", file_content, content_type="application/pdf")

        data = {
            'title': 'Contrat de Test',
            'description': 'Description du contrat de test',
            'file': uploaded_file
        }

        response = self.client.post(self.upload_url, data)
        self.assertRedirects(response, self.dashboard_url)

        # Vérification en BDD
        self.assertTrue(Document.objects.filter(title='Contrat de Test', owner=self.user).exists())
        doc = Document.objects.get(title='Contrat de Test')
        self.assertEqual(doc.status, 'draft')
        self.assertIsNotNone(doc.file_hash)
        self.assertGreater(len(doc.file_hash), 0)

        # Vérification du log d'audit
        self.assertTrue(SignatureLog.objects.filter(document=doc, action='created', user=self.user).exists())
