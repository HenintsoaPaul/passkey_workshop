from django.contrib import admin
from .models import Document, UserProfile, DocumentSigner, SignatureLog


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
