from django.test import TestCase, Client
from django.urls import reverse
from django.contrib.auth.models import User

from chiffrement_app.models import UserProfile
from .base import DEFAULT_PASSWORD


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
            password=DEFAULT_PASSWORD
        )
        self.profile = UserProfile.objects.create(
            user=self.user,
            name='John Doe',
            email='john@example.com',
            organization='CyberCorp',
            job_title='Security Engineer'
        )

    def test_profile_view_authenticated(self):
        self.client.login(username='johndoe', password=DEFAULT_PASSWORD)
        response = self.client.get(self.profile_url)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'users/profile.html')
        self.assertContains(response, 'CyberCorp')
        self.assertContains(response, 'Security Engineer')

    def test_profile_edit_success(self):
        self.client.login(username='johndoe', password=DEFAULT_PASSWORD)
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
        self.client.login(username='johndoe', password=DEFAULT_PASSWORD)
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
        self.client.login(username='johndoe', password=DEFAULT_PASSWORD)
        user_detail_url = reverse('chiffrement_app:user_detail', kwargs={'user_id': self.user.id})
        response = self.client.get(user_detail_url)
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, 'users/detail.html')
        self.assertContains(response, 'John Doe')
