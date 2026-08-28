from django.test import TestCase, Client
from django.urls import reverse
from django.contrib.auth.models import User

from chiffrement_app.models import UserProfile
from .base import DEFAULT_PASSWORD


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
            password=DEFAULT_PASSWORD
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
            'password': DEFAULT_PASSWORD
        }
        response = self.client.post(self.login_url, data)
        self.assertRedirects(response, self.dashboard_url)

    def test_logout(self):
        self.client.login(username='existinguser', password=DEFAULT_PASSWORD)
        response = self.client.get(self.logout_url)
        self.assertRedirects(response, self.login_url)
