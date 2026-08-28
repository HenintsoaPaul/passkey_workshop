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


class SigningKey(models.Model):
    """Public half of a user's RSA pair.

    The private half is generated on the phone and never leaves it, so this
    table only ever holds a PEM-encoded public key. Superseded keys are kept
    (revoked, not deleted) because a signature must be verified against the key
    that was active when it was produced, not the newest one.
    """

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='signing_keys')
    public_key_pem = models.TextField()
    algorithm = models.CharField(max_length=50, default='RSA-2048')

    # SHA-256 of the DER public key, so the phone and the server can name the
    # same key in a form a human can compare on screen.
    fingerprint = models.CharField(max_length=64, db_index=True)

    created_at = models.DateTimeField(auto_now_add=True)
    revoked_at = models.DateTimeField(null=True, blank=True)

    @property
    def is_active(self):
        return self.revoked_at is None

    def __str__(self):
        state = 'active' if self.is_active else 'révoquée'
        return f"{self.user.username} - {self.fingerprint[:16]} ({state})"

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Clé de signature'
        verbose_name_plural = 'Clés de signature'


class SigningChallenge(models.Model):
    """One-shot passkey challenge authorizing a single signing operation.

    An open session is not enough to sign: the phone asks for a challenge, the
    authenticator signs it, and the server accepts the RSA signature only if
    that assertion checks out. Binding the challenge to the user, the document
    *and* the digest being signed is what makes it authorize this signature
    rather than any signature.
    """

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='signing_challenges')
    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='signing_challenges')
    challenge = models.BinaryField()
    document_hash = models.CharField(max_length=64)

    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    consumed_at = models.DateTimeField(null=True, blank=True)

    def is_usable(self, at=None):
        at = at or timezone.now()
        return self.consumed_at is None and at < self.expires_at

    def consume(self):
        self.consumed_at = timezone.now()
        self.save(update_fields=['consumed_at'])

    def __str__(self):
        return f"{self.user.username} - {self.document.title}"

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Défi de signature'
        verbose_name_plural = 'Défis de signature'


class Signature(models.Model):
    """An RSA signature over a document's SHA-256 digest.

    `document_hash` is the digest that was actually signed. Comparing it with
    the document's current `file_hash` is what detects a document modified
    after the fact, and comparing signatures with each other is what proves
    every signer signed the same bytes.
    """

    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='signatures')
    signer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='signatures')

    # PROTECT: a key that signed something can be revoked but never deleted,
    # otherwise its signatures become unverifiable.
    signing_key = models.ForeignKey(SigningKey, on_delete=models.PROTECT, related_name='signatures')

    document_hash = models.CharField(max_length=64)
    signature_value = models.TextField(help_text='Signature RSA encodée en base64')
    algorithm = models.CharField(max_length=50, default='RSASSA-PKCS1-v1_5-SHA256')

    challenge = models.ForeignKey(
        SigningChallenge,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='signatures',
    )

    signed_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"{self.signer.username} - {self.document.title}"

    class Meta:
        ordering = ['-signed_at']
        constraints = [
            models.UniqueConstraint(
                fields=['document', 'signer'],
                name='unique_signature_per_signer_and_document',
            )
        ]
        verbose_name = 'Signature'
        verbose_name_plural = 'Signatures'