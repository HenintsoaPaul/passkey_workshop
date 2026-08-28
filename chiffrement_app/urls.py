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
    path('document/<int:document_id>/', views.document_detail, name='document_detail'),
    path('document/<int:document_id>/assign/', views.assign_signers, name='assign_signers'),
    path('document/<int:document_id>/sign/', views.sign_document, name='sign_document'),
    path('document/<int:document_id>/verify/', views.verify_document, name='verify_document'),
    path('document/<int:document_id>/archive/', views.archive_document, name='archive_document'),

    # Gestion des Utilisateurs & Profils
    path('profile/', views.profile_view, name='profile'),
    path('profile/edit/', views.profile_edit, name='profile_edit'),
    path('users/', views.user_list, name='user_list'),
    path('user/<int:user_id>/', views.user_detail, name='user_detail'),
]