from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
import hashlib


class Document(models.Model):

    STATUS_CHOICES = [
        ('draft', 'Brouillon'),
        ('pending', 'En attente de signature'),
        ('partially_signed', 'Partiellement signé'),
        ('fully_signed', 'Complètement signé'),
        ('archived', 'Archivé'),
    ]

    title = models.CharField(max_length=255, unique=True)
    description = models.TextField(blank=True, null=True)
    file = models.FileField(upload_to='documents/%Y/%m/%d/')
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='documents')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='draft')
    
    # Integrity and verification
    file_hash = models.CharField(max_length=64, blank=True)
    file_size = models.BigIntegerField(null=True)
    mime_type = models.CharField(max_length=100, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    due_date = models.DateTimeField(null=True, blank=True)

    def calculate_file_hash(self):
        """Calcule le hash SHA256 du fichier"""
        hash_sha256 = hashlib.sha256()
        for chunk in self.file.chunks():
            hash_sha256.update(chunk)
        self.file_hash = hash_sha256.hexdigest()
    
    def save(self, *args, **kwargs):
        if self.file:
            self.calculate_file_hash()
            self.file_size = self.file.size
        super().save(*args, **kwargs)

    def __str__(self):
        return self.title

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Document'
        verbose_name_plural = 'Documents'


class UserProfile(models.Model):

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    name = models.CharField(max_length=255, null=False)
    email = models.EmailField(null=False)
    phone = models.CharField(max_length=20, blank=True, null=True)
    organization = models.CharField(max_length=255, blank=True, null=True)
    job_title = models.CharField(max_length=255, blank=True, null=True)
    address = models.CharField(max_length=255, blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    signature_image = models.ImageField(upload_to='signatures/', blank=True, null=True)
    bio = models.TextField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.user.username

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Profil utilisateur'
        verbose_name_plural = 'Profils utilisateurs'


class DocumentSigner(models.Model):

    STATUS_CHOICES = [
        ('pending', 'En attente'),
        ('viewed', 'Vu'),
        ('accepted', 'Accepté'),
        ('signed', 'Signé'),
        ('rejected', 'Rejeté'),
    ]

    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='signers')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='signers')
    signature_status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    
    signature_date = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.user.username} - {self.signature_status}"

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Signataire'
        verbose_name_plural = 'Signataires'


class SignatureLog(models.Model):

    ACTION_CHOICES = [
        ('created', 'Créé'),
        ('viewed', 'Vu'),
        ('accepted', 'Accepté'),
        ('signed', 'Signé'),
        ('rejected', 'Rejeté'),
    ]

    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='logs')
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='signature_logs')
    details = models.TextField(blank=True, null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.user.username} - {self.action}"
    
    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Journal de signature'
        verbose_name_plural = 'Journaux de signature'


class Passkey(models.Model):

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='passkeys')
    credential_id = models.BinaryField(unique=True)
    public_key = models.BinaryField()
    sign_count = models.PositiveBigIntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - passkey"

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Clé d'accès"
        verbose_name_plural = "Clés d'accès"