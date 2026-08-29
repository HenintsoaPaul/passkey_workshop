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
    # fact, only superseded. `file` is deliberately absent: the admin is a web
    # surface, and §1 keeps the signed document to the mobile app.
    fields = ('version_number', 'sha256', 'file_size', 'mime_type',
              'created_at', 'created_by')
    readonly_fields = fields
    can_delete = False

    def has_add_permission(self, request, obj):
        return False


@admin.register(Document)
class DocumentAdmin(admin.ModelAdmin):
    list_display = ('title', 'owner', 'status', 'version_number', 'created_at', 'due_date')
    search_fields = ('title', 'description', 'owner__username', 'versions__sha256')
    list_filter = ('status', 'created_at', 'due_date')
    inlines = [DocumentVersionInline]

    def has_add_permission(self, request):
        """Documents are created by uploading a file, never here.

        A document created from the admin would have no version: no file, no
        digest, nothing to sign. Use the upload page, which creates version 1
        with the document.
        """
        return False

    def has_delete_permission(self, request, obj=None):
        """An unused draft can go; anything signed is evidence and stays.

        Deleting a Document cascades to its versions, signatures and log, so
        this is the last gate in front of all of them.
        """
        if obj is None:
            return True

        return not obj.signatures.exists()


@admin.register(DocumentVersion)
class DocumentVersionAdmin(admin.ModelAdmin):
    list_display = ('document', 'version_number', 'sha256', 'created_at', 'created_by')
    search_fields = ('document__title', 'sha256')
    list_filter = ('created_at',)

    # No `file`: rendering it here would put a download link to the signed
    # document in a browser, which is exactly what §1 forbids. The digest is
    # enough to audit which content a version holds.
    fields = ('document', 'version_number', 'sha256', 'file_size',
              'mime_type', 'created_at', 'created_by')
    readonly_fields = fields

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        # A version records what was signed. Removing one would leave its
        # signatures describing content nobody can produce any more.
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

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        # An audit trail with a delete button is not an audit trail.
        return False


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
    # The signature value itself is withheld — it is an electronic signature,
    # and §1 keeps those to the mobile app. Everything needed to audit one
    # (who, when, over which digest, with which key) is here.
    fields = (
        'document',
        'document_version',
        'signer',
        'signing_key',
        'document_hash',
        'signature_value_withheld',
        'algorithm',
        'challenge',
        'signed_at',
    )
    readonly_fields = fields

    @admin.display(description='Valeur de la signature')
    def signature_value_withheld(self, obj):
        return (
            'Masquée : les signatures électroniques ne sont consultables que '
            "depuis l'application mobile (§1)."
        )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        # §1: the system conserves signature information. A signature that can
        # be deleted from an admin page was never really retained.
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
