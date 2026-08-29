"""Routes for the mobile JSON API, mounted at /api/."""

from django.urls import path

from . import api

app_name = 'api'

urlpatterns = [
    path('me/', api.me, name='me'),
    path('keys/', api.signing_keys, name='signing_keys'),

    path('documents/', api.document_list, name='document_list'),
    path('documents/<int:document_id>/', api.document_detail, name='document_detail'),
    path('documents/<int:document_id>/file/', api.document_file, name='document_file'),
    path(
        'documents/<int:document_id>/verify/',
        api.document_verification,
        name='document_verification',
    ),
    path(
        'documents/<int:document_id>/sign/challenge/',
        api.sign_challenge,
        name='sign_challenge',
    ),
    path('documents/<int:document_id>/sign/', api.sign_document, name='sign_document'),
]
