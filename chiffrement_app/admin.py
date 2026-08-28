from django.contrib import admin
from .models import (
    Document,
    DocumentSigner,
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


@admin.register(Document)
class DocumentAdmin(admin.ModelAdmin):
    list_display = ('title', 'owner', 'status', 'file_size', 'created_at', 'due_date')
    search_fields = ('title', 'description', 'owner__username', 'file_hash')
    list_filter = ('status', 'created_at', 'due_date')
    readonly_fields = ('file_hash', 'file_size')


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
    list_display = ('document', 'signer', 'algorithm', 'signed_at')
    search_fields = ('document__title', 'signer__username', 'document_hash')
    list_filter = ('algorithm', 'signed_at')
    # A recorded signature is evidence: readable in the admin, never editable.
    readonly_fields = (
        'document',
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
