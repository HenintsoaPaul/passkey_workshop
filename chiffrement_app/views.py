from django.shortcuts import render
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.contrib.auth import authenticate, login, logout
from django.contrib import messages
from django.db.models import Q
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.conf import settings
import json
import uuid
import base64

from webauthn import (
    generate_registration_options,
    verify_registration_response,
    generate_authentication_options,
    verify_authentication_response,
    options_to_json,
    base64url_to_bytes,
)
from webauthn.helpers.structs import (
    AuthenticatorSelectionCriteria,
    AuthenticatorAttachment,
    ResidentKeyRequirement,
    UserVerificationRequirement,
    PublicKeyCredentialDescriptor,
)

from .models import (
    Document,
    DocumentSigner,
    Passkey,
    SignatureLog,
    SigningKey,
    UserProfile,
)
from .services import (
    add_version,
    create_document,
    recompute_document_status,
    verify_document as run_verification,
)

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
        signer_ids = request.POST.getlist('signers')
        
        if not title or not file:
            messages.error(request, 'Titre et fichier requis.')
            return redirect('chiffrement_app:upload_document')

        if Document.objects.filter(title=title).exists():
            available_users = User.objects.exclude(id=request.user.id).select_related('profile')
            messages.error(request, 'Un document avec ce titre existe déjà.')
            return render(request, 'documents/upload.html', {
                'error': 'Un document avec ce titre existe déjà.',
                'available_users': available_users
            })
        
        document = create_document(
            title=title,
            description=description,
            file=file,
            owner=request.user,
            due_date=due_date if due_date else None,
        )

        if signer_ids:
            assigned_signers = User.objects.filter(id__in=signer_ids)
            for signer_user in assigned_signers:
                DocumentSigner.objects.create(
                    document=document,
                    user=signer_user,
                    signature_status='pending'
                )
                SignatureLog.objects.create(
                    document=document,
                    action='created',
                    user=request.user,
                    details=f'Signataire {signer_user.username} affecté au document'
                )

            recompute_document_status(document)

        messages.success(request, 'Document téléversé avec succès!')
        return redirect('chiffrement_app:document_detail', document_id=document.id)
    
    available_users = User.objects.exclude(id=request.user.id).select_related('profile')
    return render(request, 'documents/upload.html', {'available_users': available_users})


@login_required(login_url='chiffrement_app:login')
def document_detail(request, document_id):
    document = get_object_or_404(Document, id=document_id)
    
    # Access check: owner or assigned signer
    is_owner = (document.owner == request.user)
    user_signer = DocumentSigner.objects.filter(document=document, user=request.user).first()
    
    if not is_owner and not user_signer and not request.user.is_staff:
        messages.error(request, "Vous n'avez pas accès à ce document.")
        return redirect('chiffrement_app:dashboard')
    
    # Track view action for assigned signers
    if user_signer and user_signer.signature_status == 'pending':
        user_signer.signature_status = 'viewed'
        user_signer.save()
        SignatureLog.objects.create(
            document=document,
            action='viewed',
            user=request.user,
            details=f'Document consulté par {request.user.username}'
        )

    signers = document.signers.select_related('user__profile').all()
    total_signers = signers.count()

    # Counted from the signatures on the current version, so the page cannot
    # claim progress the verification report would deny.
    version = document.current_version
    signed_ids = set(
        version.signatures.values_list('signer_id', flat=True) if version else []
    )
    signed_count = len(signed_ids)
    progress_pct = int((signed_count / total_signers) * 100) if total_signers > 0 else 0

    logs = document.logs.select_related('user').all()
    available_users = User.objects.exclude(id=document.owner.id).select_related('profile') if is_owner else None

    context = {
        'document': document,
        'is_owner': is_owner,
        'user_signer': user_signer,
        'signers': signers,
        'signed_ids': signed_ids,
        'total_signers': total_signers,
        'signed_count': signed_count,
        'progress_pct': progress_pct,
        'logs': logs,
        'available_users': available_users,
        'versions': document.versions.select_related('created_by__profile'),
        'current_version': version,
    }
    return render(request, 'documents/detail.html', context)


@login_required(login_url='chiffrement_app:login')
def assign_signers(request, document_id):
    document = get_object_or_404(Document, id=document_id, owner=request.user)

    if document.status == 'archived':
        messages.error(
            request,
            "Ce document est archivé : ses signataires ne peuvent plus changer.",
        )
        return redirect('chiffrement_app:document_detail', document_id=document.id)

    if request.method == 'POST':
        signer_ids = request.POST.getlist('signers')
        current_signers = DocumentSigner.objects.filter(document=document)
        
        # Add new signers
        for s_id in signer_ids:
            s_user = User.objects.filter(id=s_id).first()
            if s_user and not current_signers.filter(user=s_user).exists():
                DocumentSigner.objects.create(
                    document=document,
                    user=s_user,
                    signature_status='pending'
                )
                SignatureLog.objects.create(
                    document=document,
                    action='created',
                    user=request.user,
                    details=f'Signataire {s_user.username} affecté au document'
                )
        
        # Remove unselected signers if they haven't signed yet
        for existing in current_signers:
            if str(existing.user.id) not in signer_ids and existing.signature_status != 'signed':
                existing.delete()
                SignatureLog.objects.create(
                    document=document,
                    action='created',
                    user=request.user,
                    details=f'Signataire {existing.user.username} retiré du document'
                )
                
        # Derived centrally, from the signatures actually recorded, so this
        # view and the API can never disagree about a document's state.
        recompute_document_status(document)

        messages.success(request, 'Signataires mis à jour avec succès.')
        
    return redirect('chiffrement_app:document_detail', document_id=document.id)


@login_required(login_url='chiffrement_app:login')
def sign_document(request, document_id):
    """Signing is not possible from a browser, and says so.

    A signature requires the RSA private key, which never leaves the phone,
    and a fresh passkey confirmation (§2.1–§2.4). This view used to flip a
    status field with no cryptography behind it, which made the web app and
    the verification report disagree about whether a document was signed.
    """
    document = get_object_or_404(Document, id=document_id)
    get_object_or_404(DocumentSigner, document=document, user=request.user)

    messages.info(
        request,
        "La signature se fait depuis l'application mobile : votre clé privée "
        "ne quitte jamais votre téléphone et votre passkey doit confirmer "
        "chaque signature.",
    )

    return redirect('chiffrement_app:document_detail', document_id=document.id)


@login_required(login_url='chiffrement_app:login')
def verify_document(request, document_id):
    """Run the same verification the mobile app sees, and show every check.

    The old version compared the file against its stored hash and called that
    'verified'. That is only the fourth of the four conditions in §2.5; the
    signatures themselves were never checked.
    """
    document = get_object_or_404(Document, id=document_id)

    report = run_verification(document)

    context = {
        'document': document,
        'report': report,
        'current_hash': report['current_hash'],
        'is_valid': report['verdict'] == 'valid',
        'signers': document.signers.select_related('user__profile').all(),
        'logs': document.logs.select_related('user').all(),
    }
    return render(request, 'documents/verify.html', context)


@login_required(login_url='chiffrement_app:login')
def upload_version(request, document_id):
    """Replace a document's content, which invalidates its signatures.

    §2.5: a modified document is a new version, and everyone has to sign
    again. Nothing is overwritten — the previous version and the signatures
    made against it are kept as the record of what was agreed then.
    """
    document = get_object_or_404(Document, id=document_id, owner=request.user)

    if request.method != 'POST':
        return redirect('chiffrement_app:document_detail', document_id=document.id)

    file = request.FILES.get('file')

    if not file:
        messages.error(request, 'Aucun fichier fourni.')
        return redirect('chiffrement_app:document_detail', document_id=document.id)

    try:
        version = add_version(document, file, request.user)
    except ValueError as error:
        messages.error(request, str(error))
        return redirect('chiffrement_app:document_detail', document_id=document.id)

    messages.success(
        request,
        f'Version {version.version_number} déposée. Les signatures précédentes '
        f'ne valent plus pour ce contenu : chaque signataire doit signer à nouveau.',
    )

    return redirect('chiffrement_app:document_detail', document_id=document.id)


@login_required(login_url='chiffrement_app:login')
def archive_document(request, document_id):
    document = get_object_or_404(Document, id=document_id, owner=request.user)
    document.status = 'archived'
    document.save()
    
    SignatureLog.objects.create(
        document=document,
        action='created',
        user=request.user,
        details=f'Document archivé par {request.user.username}'
    )
    
    messages.info(request, 'Le document a été archivé.')
    return redirect('chiffrement_app:document_detail', document_id=document.id)


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
def user_create(request):
    """Let an administrator create a signatory account.

    §1 asks the web app to create and manage users; until now the only way in
    was self-registration, which leaves no way to onboard a signatory.
    """
    if not request.user.is_staff:
        messages.error(request, "Seul un administrateur peut créer un compte.")
        return redirect('chiffrement_app:user_list')

    if request.method == 'POST':
        username = (request.POST.get('username') or '').strip()
        email = (request.POST.get('email') or '').strip()
        name = (request.POST.get('name') or '').strip()
        password = request.POST.get('password') or ''

        errors = []

        if not username:
            errors.append("Le nom d'utilisateur est obligatoire.")
        elif User.objects.filter(username=username).exists():
            errors.append("Ce nom d'utilisateur existe déjà.")

        if email and User.objects.filter(email=email).exists():
            errors.append("Cet email est déjà utilisé.")

        if len(password) < 8:
            errors.append('Le mot de passe doit faire au moins 8 caractères.')

        if errors:
            for error in errors:
                messages.error(request, error)

            return render(request, 'users/create.html', {
                'form_values': {'username': username, 'email': email, 'name': name},
            })

        user = User.objects.create_user(
            username=username, email=email, password=password
        )
        user.first_name = name
        user.save()

        UserProfile.objects.create(
            user=user, name=name or username, email=email
        )

        messages.success(
            request,
            f"Compte « {username} » créé. L'utilisateur doit maintenant "
            f"enregistrer une passkey et une clé de signature depuis "
            f"l'application mobile.",
        )

        return redirect('chiffrement_app:user_detail', user_id=user.id)

    return render(request, 'users/create.html', {'form_values': {}})


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
        # Public halves only: enough to manage a user's credentials, and
        # nothing that could stand in for them.
        'signing_keys': SigningKey.objects.filter(user=user_obj),
        'passkey_count': Passkey.objects.filter(user=user_obj).count(),
    }
    return render(request, 'users/detail.html', context)


# ============ Passkeys ============

from .webauthn_config import EXPECTED_ORIGINS, ORIGIN, RP_ID, RP_NAME  # noqa: F401


def assetlinks(request):
    return JsonResponse([
        {
            'relation': [
                'delegate_permission/common.handle_all_urls',
                'delegate_permission/common.get_login_creds',
            ],
            'target': {
                'namespace': 'android_app',
                'package_name': settings.ANDROID_PACKAGE_NAME,
                'sha256_cert_fingerprints': [
                    settings.ANDROID_CERT_FINGERPRINT
                ],
            },
        }
    ], safe=False)


def passkey_error(code, detail, status=400):
    """Same envelope as the /api/ endpoints, so the client parses one shape."""
    return JsonResponse({'error': code, 'detail': detail}, status=status)


def read_passkey_body(request):
    try:
        return json.loads(request.body or b'{}')
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None


@csrf_exempt
def register_options(request):
    """Begin enrolling a passkey — but only for someone who proves who they are.

    Enrolling a passkey creates a credential that logs in without a password
    ever again, so the request has to be authenticated. It previously took a
    username alone and called get_or_create, which meant anyone could invent
    an account, or bind their own passkey to somebody else's username and sign
    in as them.

    The account password is used here and only here: once the passkey exists,
    logging in never asks for it again.
    """
    if request.method != 'POST':
        return passkey_error('method_not_allowed', 'POST requis.', status=405)

    body = read_passkey_body(request)

    if body is None:
        return passkey_error('invalid_json', 'Corps de requête illisible.')

    username = (body.get('username') or '').strip()
    password = body.get('password') or ''

    if not username:
        return passkey_error('missing_username', "Saisissez votre nom d'utilisateur.")

    if not password:
        return passkey_error(
            'missing_password',
            'Saisissez le mot de passe de votre compte pour créer une passkey.',
        )

    user = authenticate(request, username=username, password=password)

    if user is None:
        # One message for both cases on purpose: distinguishing them would
        # confirm which usernames exist.
        return passkey_error(
            'invalid_credentials',
            "Nom d'utilisateur ou mot de passe incorrect.",
            status=401,
        )

    request.session['registration_user'] = user.id

    options = generate_registration_options(
        rp_id=RP_ID,
        rp_name=RP_NAME,
        user_id=uuid.uuid4().bytes,
        user_name=user.username,
        user_display_name=user.username,
        authenticator_selection=AuthenticatorSelectionCriteria(
            authenticator_attachment=AuthenticatorAttachment.PLATFORM,
            resident_key=ResidentKeyRequirement.REQUIRED,
            user_verification=UserVerificationRequirement.PREFERRED,
        ),
    )

    request.session['registration_challenge'] = base64.urlsafe_b64encode(options.challenge).decode().rstrip('=')

    return JsonResponse(json.loads(options_to_json(options)))


@csrf_exempt
def register_verify(request):
    if request.method != 'POST':
        return JsonResponse({'error': 'POST required'}, status=405)

    body = read_passkey_body(request)

    if body is None:
        return passkey_error('invalid_json', 'Corps de requête illisible.')

    username = (body.get('username') or '').strip()
    credential = body.get('credential')

    stored_challenge = request.session.get('registration_challenge')
    challenge = (
        base64.urlsafe_b64decode(stored_challenge + '==') if stored_challenge else None
    )
    user_id = request.session.get('registration_user')

    if not challenge or not user_id:
        return passkey_error(
            'no_ceremony',
            "La création de la passkey a expiré. Recommencez depuis le début.",
        )

    # The ceremony has to finish for the account that started it, so a reply
    # cannot be redirected onto a different user.
    user = User.objects.filter(id=user_id, username=username).first()

    if user is None:
        return passkey_error(
            'ceremony_mismatch',
            "Cette création de passkey ne correspond pas au compte vérifié.",
        )

    if not credential:
        return passkey_error('missing_credential', 'Aucune passkey reçue.')

    try:
        verification = verify_registration_response(
            credential=credential,
            expected_challenge=challenge,
            expected_rp_id=RP_ID,
            expected_origin=EXPECTED_ORIGINS,
            require_user_verification=False,
        )
    except Exception as error:
        return passkey_error(
            'passkey_rejected',
            f"La passkey n'a pas pu être vérifiée : {error}",
        )

    Passkey.objects.create(
        user=user,
        credential_id=verification.credential_id,
        public_key=verification.credential_public_key,
        sign_count=verification.sign_count,
    )

    request.session.pop('registration_challenge', None)
    request.session.pop('registration_user', None)

    return JsonResponse({'success': True, 'username': username})


@csrf_exempt
def login_options(request):
    if request.method != 'POST':
        return passkey_error('method_not_allowed', 'POST requis.', status=405)

    body = read_passkey_body(request)

    if body is None:
        return passkey_error('invalid_json', 'Corps de requête illisible.')

    username = (body.get('username') or '').strip()

    if not username:
        return passkey_error('missing_username', "Saisissez votre nom d'utilisateur.")

    user = User.objects.filter(username=username).first()
    passkeys = list(Passkey.objects.filter(user=user)) if user else []

    if not passkeys:
        # Deliberately the same answer whether the account is unknown or simply
        # has no passkey yet: actionable for the owner, uninformative to
        # someone probing for usernames.
        return passkey_error(
            'no_passkey',
            "Aucune passkey n'est associée à ce compte sur ce serveur. "
            "Créez-en une avec le mot de passe de votre compte.",
            status=404,
        )

    allow_credentials = [
        PublicKeyCredentialDescriptor(id=bytes(pk.credential_id))
        for pk in passkeys
    ]

    options = generate_authentication_options(
        rp_id=RP_ID,
        allow_credentials=allow_credentials,
        user_verification=UserVerificationRequirement.PREFERRED,
    )

    request.session['authentication_challenge'] = base64.urlsafe_b64encode(options.challenge).decode().rstrip('=')
    request.session['authentication_user'] = user.id

    return JsonResponse(json.loads(options_to_json(options)))


def _verified_assertion(credential, challenge, passkey):
    """Check a WebAuthn assertion, returning None instead of raising.

    A passkey the server cannot verify is an expected outcome — a stale
    credential, a different device — and deserves a 401 with an explanation
    rather than a 500 with a stack trace.
    """
    try:
        return verify_authentication_response(
            credential=credential,
            expected_challenge=challenge,
            expected_rp_id=RP_ID,
            expected_origin=EXPECTED_ORIGINS,
            credential_public_key=bytes(passkey.public_key),
            credential_current_sign_count=passkey.sign_count,
            require_user_verification=False,
        )
    except Exception:
        return None


@csrf_exempt
def login_verify(request):
    if request.method != 'POST':
        return passkey_error('method_not_allowed', 'POST requis.', status=405)

    body = read_passkey_body(request)

    if body is None:
        return passkey_error('invalid_json', 'Corps de requête illisible.')

    credential = body.get('credential')

    stored_challenge = request.session.get('authentication_challenge')
    challenge = (
        base64.urlsafe_b64decode(stored_challenge + '==') if stored_challenge else None
    )
    user_id = request.session.get('authentication_user')

    if not challenge or not user_id:
        return passkey_error(
            'no_ceremony',
            'La connexion a expiré. Réessayez de vous connecter.',
        )

    if not credential or not credential.get('rawId'):
        return passkey_error('missing_credential', 'Aucune passkey reçue.')

    user = User.objects.filter(id=user_id).first()
    passkey = (
        Passkey.objects.filter(
            user=user, credential_id=base64url_to_bytes(credential['rawId'])
        ).first()
        if user
        else None
    )

    if passkey is None:
        return passkey_error(
            'unknown_passkey',
            "Cette passkey n'est pas enregistrée pour ce compte sur ce serveur.",
            status=401,
        )

    verification = _verified_assertion(credential, challenge, passkey)

    if verification is None:
        return passkey_error(
            'passkey_rejected',
            "La passkey n'a pas pu être vérifiée par le serveur.",
            status=401,
        )

    passkey.sign_count = verification.new_sign_count
    passkey.save(update_fields=['sign_count'])

    # Establish the session the mobile JSON API authenticates against. Without
    # this the client holds a cookie for an anonymous session and every
    # /api/ call comes back 401.
    login(request, user, backend='django.contrib.auth.backends.ModelBackend')

    request.session.pop('authentication_challenge', None)
    request.session.pop('authentication_user', None)

    return JsonResponse({'success': True, 'username': user.username})