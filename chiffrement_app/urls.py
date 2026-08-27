from django.contrib import admin
from django.urls import path
from . import views

app_name = "chiffrement_app"
urlpatterns = [
    # Authentification
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('register/', views.register, name='register'),

    path('', views.dashboard, name='dashboard'),
    path('document/upload/', views.upload_document, name='upload_document'),
    #path('document/<int:document_id>/', views.document_detail, name='document_detail'),
    #path('document/<int:document_id>/sign/', views.sign_document, name='sign_document'),
    #path('document/<int:document_id>/download/', views.download_document, name='download_document'),
    #path('document/<int:document_id>/archive/', views.archive_document, name='archive_document'),
    #path('document/<int:document_id>/share/', views.share_document, name='share_document'),
    #path('document/<int:document_id>/revoke/', views.revoke_document, name='revoke_document'),
]