from django.contrib import admin
from .models import (
    Document,
    DocumentSigner,
    DocumentVersion,
    Signature,
    SignatureLog,
    SigningChallenge,
    SigningKey,
    UserProfile,
)


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'name', 'email', 'organization', 'job_title', 'phone', 'created_at')
    search_fields = ('user__username', 'name', 'email', 'organization', 'job_title')
    list_filter = ('created_at', 'organization')


class DocumentVersionInline(admin.TabularInline):
    model = DocumentVersion
    extra = 0
    # A version is a record of what was signed; it is never edited after the
    # fact, only superseded.
    readonly_fields = (
        'version_number', 'file', 'sha256', 'file_size', 'mime_type',
        'created_at', 'created_by',
    )
    can_delete = False

    def has_add_permission(self, request, obj):
        return False


@admin.register(Document)
class DocumentAdmin(admin.ModelAdmin):
    list_display = ('title', 'owner', 'status', 'version_number', 'created_at', 'due_date')
    search_fields = ('title', 'description', 'owner__username', 'versions__sha256')
    list_filter = ('status', 'created_at', 'due_date')
    inlines = [DocumentVersionInline]


@admin.register(DocumentVersion)
class DocumentVersionAdmin(admin.ModelAdmin):
    list_display = ('document', 'version_number', 'sha256', 'created_at', 'created_by')
    search_fields = ('document__title', 'sha256')
    list_filter = ('created_at',)
    readonly_fields = (
        'document', 'version_number', 'file', 'sha256', 'file_size',
        'mime_type', 'created_at', 'created_by',
    )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(DocumentSigner)
class DocumentSignerAdmin(admin.ModelAdmin):
    list_display = ('document', 'user', 'signature_status', 'signature_date', 'created_at')
    search_fields = ('document__title', 'user__username')
    list_filter = ('signature_status', 'signature_date')


@admin.register(SignatureLog)
class SignatureLogAdmin(admin.ModelAdmin):
    list_display = ('document', 'action', 'user', 'created_at')
    search_fields = ('document__title', 'user__username', 'details')
    list_filter = ('action', 'created_at')
    readonly_fields = ('document', 'action', 'user', 'details', 'created_at')


@admin.register(SigningKey)
class SigningKeyAdmin(admin.ModelAdmin):
    list_display = ('user', 'algorithm', 'fingerprint', 'created_at', 'revoked_at')
    search_fields = ('user__username', 'fingerprint')
    list_filter = ('algorithm', 'created_at')
    readonly_fields = ('public_key_pem', 'fingerprint', 'algorithm', 'created_at')


@admin.register(Signature)
class SignatureAdmin(admin.ModelAdmin):
    list_display = ('document', 'document_version', 'signer', 'algorithm', 'signed_at')
    search_fields = ('document__title', 'signer__username', 'document_hash')
    list_filter = ('algorithm', 'signed_at')
    # A recorded signature is evidence: readable in the admin, never editable.
    readonly_fields = (
        'document',
        'document_version',
        'signer',
        'signing_key',
        'document_hash',
        'signature_value',
        'algorithm',
        'challenge',
        'signed_at',
    )

    def has_add_permission(self, request):
        return False


@admin.register(SigningChallenge)
class SigningChallengeAdmin(admin.ModelAdmin):
    list_display = ('user', 'document', 'created_at', 'expires_at', 'consumed_at')
    search_fields = ('user__username', 'document__title')
    list_filter = ('created_at', 'consumed_at')
    readonly_fields = (
        'user',
        'document',
        'challenge',
        'document_hash',
        'created_at',
        'expires_at',
        'consumed_at',
    )

    def has_add_permission(self, request):
        return False
