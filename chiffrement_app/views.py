from django.shortcuts import render
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.contrib.auth import authenticate, login, logout
from django.contrib import messages
from django.db.models import Q
from django.http import JsonResponse, FileResponse
from django.views.decorators.http import require_http_methods
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
import hashlib
import json
from datetime import timedelta

from .models import Document, DocumentSigner, UserProfile, SignatureLog

# ============ Authentification ============

def register(request):
    if request.method == 'POST':
        username = request.POST.get('username')
        email = request.POST.get('email')
        password = request.POST.get('password')
        password_confirm = request.POST.get('password_confirm')
        name = request.POST.get('name', '')
        phone = request.POST.get('phone', '')
        address = request.POST.get('address', '')
        city = request.POST.get('city', '')
        
        if password != password_confirm:
            messages.error(request, 'Les mots de passe ne correspondent pas')
            return render(request, 'register.html', {'error': 'Les mots de passe ne correspondent pas'})
        
        if User.objects.filter(username=username).exists():
            messages.error(request, 'Le nom d\'utilisateur existe déjà')
            return render(request, 'register.html', {'error': 'Le nom d\'utilisateur existe déjà'})
        
        if User.objects.filter(email=email).exists():
            messages.error(request, 'L\'email existe déjà')
            return render(request, 'register.html', {'error': 'L\'email existe déjà'})
        
        user = User.objects.create_user(username=username, email=email, password=password)
        user.first_name = name
        user.save()
        
        profile = UserProfile.objects.create(user=user, name=name, email=email, phone=phone, address=address, city=city)
        profile.save()
        
        messages.success(request, 'Votre compte a été créé avec succès')
        return redirect('chiffrement_app:login')
    
    return render(request, 'register.html')


def login_view(request):
    if request.user.is_authenticated:
        return redirect('chiffrement_app:dashboard')
    
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            login(request, user)
            messages.success(request, 'Vous êtes connecté')
            return redirect('chiffrement_app:dashboard')
        else:
            messages.error(request, 'Nom d\'utilisateur ou mot de passe incorrect')
            return render(request, 'login.html', {'error': 'Nom d\'utilisateur ou mot de passe incorrect'})
    
    return render(request, 'login.html')

    
def logout_view(request):
    logout(request)
    return redirect('chiffrement_app:login')

# ======== Dashboard ========

@login_required(login_url='chiffrement_app:login')
def dashboard(request):
    documents = Document.objects.filter(owner=request.user)
    signature_tasks = DocumentSigner.objects.filter(
        user=request.user,
        signature_status__in=['pending', 'viewed']
    ).select_related('document')
    
    context = {
        'documents_count': documents.count(),
        'pending_signatures': signature_tasks.count(),
        'recent_documents': documents[:5],
        'recent_tasks': signature_tasks[:5],
    }
    
    return render(request, 'dashboard.html', context)

# ======== Gestion des documents ======== 

@login_required(login_url='chiffrement_app:login')
def upload_document(request):
    if request.method == 'POST':
        title = request.POST.get('title')
        description = request.POST.get('description', '')
        file = request.FILES.get('file')
        due_date = request.POST.get('due_date')
        
        if not title or not file:
            messages.error(request, 'Titre et fichier requis.')
            return redirect('chiffrement_app:upload_document')

        if Document.objects.filter(title=title).exists():
            messages.error(request, 'Un document avec ce titre existe déjà.')
            return render(request, 'documents/upload.html', {'error': 'Un document avec ce titre existe déjà.'})
        
        document = Document.objects.create(
            title=title,
            description=description,
            file=file,
            owner=request.user,
            status='draft',
            due_date=due_date if due_date else None
        )
        
        SignatureLog.objects.create(
            document=document,
            action='created',
            user=request.user,
            details=f'Document "{title}" créé'
        )
        
        messages.success(request, 'Document téléchargé avec succès!')

        # ici je voudrais rediriger vers la page de detail du document mais pour le moment on va vers dashboard
        return redirect('chiffrement_app:dashboard')
        #return redirect('chiffrement_app:document_detail', document_id=document.id)
    
    return render(request, 'documents/upload.html')


# ============ Gestion des utilisateurs ============

@login_required(login_url='chiffrement_app:login')
def profile_view(request):
    profile, created = UserProfile.objects.get_or_create(
        user=request.user,
        defaults={'name': request.user.get_full_name() or request.user.username, 'email': request.user.email}
    )
    documents_count = Document.objects.filter(owner=request.user).count()
    signatures_count = DocumentSigner.objects.filter(user=request.user, signature_status='signed').count()
    
    context = {
        'profile': profile,
        'documents_count': documents_count,
        'signatures_count': signatures_count,
    }
    return render(request, 'users/profile.html', context)


@login_required(login_url='chiffrement_app:login')
def profile_edit(request):
    profile, created = UserProfile.objects.get_or_create(
        user=request.user,
        defaults={'name': request.user.get_full_name() or request.user.username, 'email': request.user.email}
    )
    
    if request.method == 'POST':
        name = request.POST.get('name')
        email = request.POST.get('email')
        phone = request.POST.get('phone')
        organization = request.POST.get('organization')
        job_title = request.POST.get('job_title')
        address = request.POST.get('address')
        city = request.POST.get('city')
        bio = request.POST.get('bio')
        
        if 'signature_image' in request.FILES:
            profile.signature_image = request.FILES['signature_image']
            
        profile.name = name or profile.name
        profile.email = email or profile.email
        profile.phone = phone
        profile.organization = organization
        profile.job_title = job_title
        profile.address = address
        profile.city = city
        profile.bio = bio
        profile.save()
        
        if name:
            request.user.first_name = name
        if email:
            request.user.email = email
        request.user.save()
        
        messages.success(request, 'Votre profil a été mis à jour avec succès.')
        return redirect('chiffrement_app:profile')
        
    return render(request, 'users/profile_edit.html', {'profile': profile})


@login_required(login_url='chiffrement_app:login')
def user_list(request):
    query = request.GET.get('q', '').strip()
    users = User.objects.all().select_related('profile')
    
    if query:
        users = users.filter(
            Q(username__icontains=query) |
            Q(first_name__icontains=query) |
            Q(email__icontains=query) |
            Q(profile__organization__icontains=query) |
            Q(profile__job_title__icontains=query)
        )
        
    return render(request, 'users/list.html', {'users': users, 'query': query})


@login_required(login_url='chiffrement_app:login')
def user_detail(request, user_id):
    user_obj = get_object_or_404(User, id=user_id)
    profile = getattr(user_obj, 'profile', None)
    
    documents = Document.objects.filter(owner=user_obj)
    signatures = DocumentSigner.objects.filter(user=user_obj)
    
    context = {
        'target_user': user_obj,
        'profile': profile,
        'documents': documents,
        'signatures': signatures,
        'is_own_profile': request.user == user_obj,
    }
    return render(request, 'users/detail.html', context)