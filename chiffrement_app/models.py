from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from django.utils.functional import cached_property


class Document(models.Model):
    """A document to be signed, independent of the bytes it currently holds.

    The file itself lives in [DocumentVersion]. §2.5 requires that modifying a
    document create a new version and invalidate the signatures, which is only
    expressible if the content is versioned separately from the document that
    owns it.
    """

    STATUS_CHOICES = [
        ('draft', 'Brouillon'),
        ('pending', 'En attente de signature'),
        ('partially_signed', 'Partiellement signé'),
        ('fully_signed', 'Complètement signé'),
        ('archived', 'Archivé'),
    ]

    title = models.CharField(max_length=255, unique=True)
    description = models.TextField(blank=True, null=True)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='documents')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='draft')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    due_date = models.DateTimeField(null=True, blank=True)

    @cached_property
    def current_version(self):
        """The newest version — the only one that can still be signed."""
        return self.versions.first()

    def refresh_current_version(self):
        """Forget the cached version, after adding a new one."""
        self.__dict__.pop('current_version', None)

    def refresh_from_db(self, *args, **kwargs):
        # Django reloads the columns but knows nothing about the cached
        # relation, so a caller that reloaded a document would otherwise keep
        # reading the version it had before a new one was deposited.
        super().refresh_from_db(*args, **kwargs)
        self.refresh_current_version()

    # The current version's fields, read straight off the document so callers
    # and templates do not each have to walk the relation.

    @property
    def file(self):
        version = self.current_version
        return version.file if version else None

    @property
    def file_hash(self):
        version = self.current_version
        return version.sha256 if version else ''

    @property
    def file_size(self):
        version = self.current_version
        return version.file_size if version else None

    @property
    def mime_type(self):
        version = self.current_version
        return version.mime_type if version else ''

    @property
    def version_number(self):
        version = self.current_version
        return version.version_number if version else 0

    def __str__(self):
        return self.title

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Document'
        verbose_name_plural = 'Documents'


class DocumentVersion(models.Model):
    """One immutable revision of a document's content.

    Every signature names the version it covers, so "all signers signed the
    same version" is a fact about the data rather than something the code has
    to remember to check. Superseded versions are kept: their signatures stay
    verifiable as a record of what was agreed at the time.
    """

    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='versions')
    version_number = models.PositiveIntegerField()

    file = models.FileField(upload_to='documents/%Y/%m/%d/')
    sha256 = models.CharField(max_length=64)
    file_size = models.BigIntegerField(null=True)
    mime_type = models.CharField(max_length=100, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='document_versions',
    )

    @property
    def is_current(self):
        current = self.document.current_version
        return current is not None and current.pk == self.pk

    def __str__(self):
        return f"{self.document.title} - v{self.version_number}"

    class Meta:
        ordering = ['-version_number']
        constraints = [
            models.UniqueConstraint(
                fields=['document', 'version_number'],
                name='unique_version_number_per_document',
            )
        ]
        verbose_name = 'Version de document'
        verbose_name_plural = 'Versions de document'


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
        constraints = [
            # The state machine counts signers against signatures; a duplicate
            # row would inflate the total and leave the document permanently
            # short of "fully signed".
            models.UniqueConstraint(
                fields=['document', 'user'],
                name='unique_signer_per_document',
            )
        ]
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
    document_version = models.ForeignKey(
        'DocumentVersion',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='signing_challenges',
    )
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
    """An RSA signature over one version's SHA-256 digest.

    `document_version` says which revision was signed and `document_hash` is
    the digest that was actually put through the private key. Keeping both
    means a tampered row is caught too: the digest must still match the
    version it claims to cover.

    A superseded version keeps its signatures. They remain mathematically
    valid for the bytes they covered; they simply no longer count towards the
    current version, which is what §2.5 requires.
    """

    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='signatures')
    document_version = models.ForeignKey(
        'DocumentVersion',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='signatures',
    )
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
                fields=['document_version', 'signer'],
                name='unique_signature_per_signer_and_version',
            )
        ]
        verbose_name = 'Signature'
        verbose_name_plural = 'Signatures'