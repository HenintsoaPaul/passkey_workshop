"""JSON API consumed by the Flutter app.

Plain Django views rather than DRF: the four passkey endpoints already in
`views.py` are written this way, and the payloads here are small enough that
serializers would add indirection without adding safety.

Authentication is the session cookie established by the passkey login. Every
endpoint is CSRF-exempt because the caller is a native app with no browser
origin to protect; Django's default `SESSION_COOKIE_SAMESITE = 'Lax'` is what
keeps a browser from replaying these cross-site.
"""

import json
import os
from datetime import timedelta
from functools import wraps

from django.conf import settings
from django.http import FileResponse, JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from webauthn import (
    base64url_to_bytes,
    generate_authentication_options,
    options_to_json,
    verify_authentication_response,
)
from webauthn.helpers.structs import (
    PublicKeyCredentialDescriptor,
    UserVerificationRequirement,
)

from .crypto import (
    InvalidPublicKey,
    key_algorithm_label,
    public_key_fingerprint,
    verify_signature,
)
from .models import (
    Document,
    DocumentSigner,
    Passkey,
    Signature,
    SigningChallenge,
    SigningKey,
)
from .services import (
    current_document_hash,
    mark_signer_signed,
    recompute_document_status,
    verify_document,
)
from .webauthn_config import EXPECTED_ORIGINS, RP_ID


class ApiError(Exception):
    """An expected failure, rendered as `{"error": code, "detail": ...}`."""

    def __init__(self, code, detail=None, status=400):
        super().__init__(detail or code)
        self.code = code
        self.detail = detail
        self.status = status


def endpoint(*methods, require_login=True):
    """Method allow-list, session check, JSON body parsing and error rendering."""

    def decorator(view):
        @csrf_exempt
        @wraps(view)
        def wrapper(request, *args, **kwargs):
            if request.method not in methods:
                return JsonResponse(
                    {
                        'error': 'method_not_allowed',
                        'detail': f'Méthodes autorisées : {", ".join(methods)}.',
                    },
                    status=405,
                )

            if require_login and not request.user.is_authenticated:
                return JsonResponse(
                    {
                        'error': 'authentication_required',
                        'detail': "Connectez-vous avec votre passkey.",
                    },
                    status=401,
                )

            try:
                return view(request, *args, **kwargs)
            except ApiError as exc:
                return JsonResponse(
                    {'error': exc.code, 'detail': exc.detail}, status=exc.status
                )

        return wrapper

    return decorator


def read_json(request):
    try:
        return json.loads(request.body or b'{}')
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise ApiError('invalid_json', f'Corps de requête illisible : {exc}') from exc


def required(body, field):
    value = body.get(field)

    if value in (None, ''):
        raise ApiError('missing_field', f'Champ obligatoire manquant : {field}.')

    return value


# ============ Serialization ============


def display_name(user):
    profile = getattr(user, 'profile', None)

    if profile and profile.name:
        return profile.name

    return user.get_full_name() or user.username


def user_email(user):
    profile = getattr(user, 'profile', None)

    if profile and profile.email:
        return profile.email

    return user.email or ''


def iso(value):
    return value.isoformat() if value else None


def folder_path(document):
    """Breadcrumb for the detail screen, taken from where the file really sits."""
    if not document.file:
        return '/'

    parts = document.file.name.split('/')[:-1]

    return '/ ' + ' / '.join(parts) if parts else '/'


def serialize_signer(signer, current_user, signature=None):
    return {
        'username': signer.user.username,
        'name': display_name(signer.user),
        'email': user_email(signer.user),
        'status': 'signed' if signature else signer.signature_status,
        'signedAt': iso(signature.signed_at if signature else signer.signature_date),
        'isCurrentUser': signer.user_id == current_user.id,
        'keyFingerprint': signature.signing_key.fingerprint if signature else None,
    }


def serialize_log(log):
    return {
        'action': log.action,
        'title': log.get_action_display(),
        'description': log.details or '',
        'timestamp': iso(log.created_at),
        'actor': display_name(log.user),
    }


def serialize_document(document, user, include_audit=False):
    signers = list(document.signers.select_related('user__profile'))
    version = document.current_version

    # Only the current version's signatures count towards progress.
    signatures = {
        signature.signer_id: signature
        for signature in (
            version.signatures.select_related('signing_key')
            if version is not None
            else []
        )
    }

    payload = {
        'id': str(document.id),
        'title': document.title,
        'description': document.description or '',
        'status': document.status,
        'owner': display_name(document.owner),
        'ownerUsername': document.owner.username,
        'fileHash': document.file_hash,
        'fileSize': document.file_size,
        'versionNumber': document.version_number,
        'versionCount': document.versions.count(),
        'createdAt': iso(document.created_at),
        'updatedAt': iso(document.updated_at),
        'dueDate': iso(document.due_date),
        'folderPath': folder_path(document),
        'algorithm': 'SHA-256 with RSA-2048',
        'signerCount': len(signers),
        'signedCount': len(signatures),
        'signers': [
            serialize_signer(signer, user, signatures.get(signer.user_id))
            for signer in signers
        ],
        'isSigner': any(signer.user_id == user.id for signer in signers),
        'hasSigned': user.id in signatures,
        'canSign': (
            any(signer.user_id == user.id for signer in signers)
            and user.id not in signatures
            and document.status != 'archived'
        ),
    }

    if include_audit:
        payload['auditTrail'] = [
            serialize_log(log)
            for log in document.logs.select_related('user__profile')
        ]
    else:
        payload['auditTrail'] = []

    return payload


def serialize_verification(report):
    return {
        'documentId': str(report['document_id']),
        'verdict': report['verdict'],
        'status': report['status'],
        'versionNumber': report['version_number'],
        'versionCount': report['version_count'],
        'currentHash': report['current_hash'],
        'storedHash': report['stored_hash'],
        'signedCount': report['signed_count'],
        'requiredCount': report['required_count'],
        'missingSigners': report['missing_signers'],
        'checks': [
            {
                'code': check['code'],
                'label': check['label'],
                'passed': check['passed'],
                'detail': check['detail'],
            }
            for check in report['checks']
        ],
        'signatures': [
            {
                'signer': signature['signer'],
                'signerName': signature['signer_name'],
                'signedAt': iso(signature['signed_at']),
                'algorithm': signature['algorithm'],
                'documentHash': signature['document_hash'],
                'keyFingerprint': signature['key_fingerprint'],
                'isValid': signature['is_valid'],
                'reason': signature['reason'],
            }
            for signature in report['signatures']
        ],
    }


# ============ Access control ============


def visible_documents(user):
    """Documents the signed-in user may open on the phone.

    Assigned signers, per §1, plus owners — the spec also says a signed
    document is only visible in the mobile app, so an owner has nowhere else
    to look at their own.
    """
    return (
        Document.objects.filter(signers__user=user)
        | Document.objects.filter(owner=user)
    ).distinct().select_related('owner__profile')


def get_visible_document(user, document_id):
    document = visible_documents(user).filter(id=document_id).first()

    if document is None:
        raise ApiError(
            'not_found',
            "Ce document n'existe pas ou ne vous est pas affecté.",
            status=404,
        )

    return document


def active_signing_key(user):
    return (
        SigningKey.objects.filter(user=user, revoked_at__isnull=True)
        .order_by('-created_at')
        .first()
    )


# ============ Identity and keys ============


@endpoint('GET')
def me(request):
    key = active_signing_key(request.user)

    return JsonResponse({
        'username': request.user.username,
        'name': display_name(request.user),
        'email': user_email(request.user),
        'hasSigningKey': key is not None,
        'signingKey': serialize_key(key) if key else None,
        'passkeyCount': Passkey.objects.filter(user=request.user).count(),
    })


def serialize_key(key):
    return {
        'id': key.id,
        'algorithm': key.algorithm,
        'fingerprint': key.fingerprint,
        'createdAt': iso(key.created_at),
    }


@endpoint('GET', 'POST')
def signing_keys(request):
    """Register the public half of the phone's RSA pair, or read the current one.

    Only ever receives a public key. A request carrying anything that parses as
    a private key is rejected outright rather than quietly ignored, so a client
    bug cannot turn into a leaked key sitting in the database.
    """
    if request.method == 'GET':
        key = active_signing_key(request.user)

        return JsonResponse({'signingKey': serialize_key(key) if key else None})

    body = read_json(request)
    pem = required(body, 'publicKeyPem')

    if 'PRIVATE KEY' in pem:
        raise ApiError(
            'private_key_rejected',
            "La clé privée ne doit jamais quitter le téléphone.",
        )

    try:
        fingerprint = public_key_fingerprint(pem)
        algorithm = key_algorithm_label(pem)
    except InvalidPublicKey as exc:
        raise ApiError('invalid_public_key', str(exc)) from exc

    existing = SigningKey.objects.filter(
        user=request.user, fingerprint=fingerprint, revoked_at__isnull=True
    ).first()

    if existing:
        return JsonResponse({'signingKey': serialize_key(existing), 'created': False})

    # A phone that regenerated its pair supersedes the old key; the old rows
    # stay so their existing signatures remain verifiable.
    SigningKey.objects.filter(user=request.user, revoked_at__isnull=True).update(
        revoked_at=timezone.now()
    )

    key = SigningKey.objects.create(
        user=request.user,
        public_key_pem=pem,
        algorithm=algorithm,
        fingerprint=fingerprint,
    )

    return JsonResponse({'signingKey': serialize_key(key), 'created': True}, status=201)


# ============ Documents ============


@endpoint('GET')
def document_list(request):
    documents = visible_documents(request.user).prefetch_related(
        'signers__user__profile', 'signatures__signing_key'
    )

    return JsonResponse({
        'documents': [
            serialize_document(document, request.user) for document in documents
        ]
    })


@endpoint('GET')
def document_detail(request, document_id):
    document = get_visible_document(request.user, document_id)

    return JsonResponse(serialize_document(document, request.user, include_audit=True))


@endpoint('GET')
def document_file(request, document_id):
    """The exact bytes the signature covers.

    The phone hashes what it downloads here rather than trusting `fileHash`;
    that is the whole point of computing the digest client-side.
    """
    document = get_visible_document(request.user, document_id)

    if not document.file:
        raise ApiError('file_missing', 'Aucun fichier attaché.', status=404)

    try:
        handle = document.file.open('rb')
    except (FileNotFoundError, OSError) as exc:
        raise ApiError(
            'file_unreadable', f'Fichier illisible : {exc}', status=404
        ) from exc

    response = FileResponse(handle, as_attachment=True, filename=document.file.name.split('/')[-1])
    response['X-Document-Hash'] = document.file_hash

    return response


@endpoint('GET')
def document_verification(request, document_id):
    document = get_visible_document(request.user, document_id)

    return JsonResponse(serialize_verification(verify_document(document)))


# ============ Signing ============


def assert_can_sign(user, document):
    signer = DocumentSigner.objects.filter(document=document, user=user).first()

    if signer is None:
        raise ApiError(
            'not_a_signer', "Vous n'êtes pas signataire de ce document.", status=403
        )

    if document.status == 'archived':
        raise ApiError('document_archived', 'Ce document est archivé.')

    version = document.current_version

    if version is None:
        raise ApiError('no_version', "Ce document n'a aucun contenu.")

    if Signature.objects.filter(document_version=version, signer=user).exists():
        raise ApiError(
            'already_signed',
            'Vous avez déjà signé cette version du document.',
            status=409,
        )

    return signer


@endpoint('POST')
def sign_challenge(request, document_id):
    """Issue the passkey challenge that authorizes one signature.

    §2.1: an open session is not enough. The challenge is single-use, expires
    in minutes, and is bound to this user, this document and this digest, so
    the assertion it produces cannot authorize anything else.
    """
    document = get_visible_document(request.user, document_id)
    assert_can_sign(request.user, document)

    key = active_signing_key(request.user)

    if key is None:
        raise ApiError(
            'no_signing_key',
            "Aucune clé de signature enregistrée pour ce compte.",
        )

    passkeys = list(Passkey.objects.filter(user=request.user))

    if not passkeys:
        raise ApiError('no_passkey', "Aucune passkey enregistrée pour ce compte.")

    current_hash = current_document_hash(document)

    if current_hash is None:
        raise ApiError('file_unreadable', 'Le fichier du document est illisible.')

    submitted_hash = required(read_json(request), 'documentHash').lower()

    if submitted_hash != current_hash:
        raise ApiError(
            'hash_mismatch',
            "L'empreinte calculée sur le téléphone ne correspond pas au "
            "document actuel. Rechargez le document.",
        )

    challenge_bytes = os.urandom(32)

    challenge = SigningChallenge.objects.create(
        user=request.user,
        document=document,
        document_version=document.current_version,
        challenge=challenge_bytes,
        document_hash=current_hash,
        expires_at=timezone.now()
        + timedelta(seconds=settings.SIGNING_CHALLENGE_TTL_SECONDS),
    )

    options = generate_authentication_options(
        rp_id=RP_ID,
        challenge=challenge_bytes,
        allow_credentials=[
            PublicKeyCredentialDescriptor(id=bytes(passkey.credential_id))
            for passkey in passkeys
        ],
        user_verification=(
            UserVerificationRequirement.REQUIRED
            if settings.SIGNING_REQUIRE_USER_VERIFICATION
            else UserVerificationRequirement.PREFERRED
        ),
    )

    return JsonResponse({
        'challengeId': challenge.id,
        'documentHash': current_hash,
        'versionNumber': document.version_number,
        'keyFingerprint': key.fingerprint,
        'expiresAt': iso(challenge.expires_at),
        'publicKeyOptions': json.loads(options_to_json(options)),
    })


@endpoint('POST')
def sign_document(request, document_id):
    """Record a signature, once the passkey assertion and the RSA both check out.

    Order matters: the passkey confirmation is verified first, because it is
    what authorizes the operation. Only then is the RSA signature checked
    against the digest the challenge was issued for.
    """
    document = get_visible_document(request.user, document_id)
    assert_can_sign(request.user, document)

    body = read_json(request)
    challenge_id = required(body, 'challengeId')
    credential = required(body, 'credential')
    signature_b64 = required(body, 'signature')

    challenge = SigningChallenge.objects.filter(
        id=challenge_id, user=request.user, document=document
    ).first()

    if challenge is None:
        raise ApiError('unknown_challenge', 'Défi de signature introuvable.')

    if not challenge.is_usable():
        raise ApiError(
            'challenge_expired',
            'Ce défi a expiré ou a déjà été utilisé. Recommencez la signature.',
        )

    key = active_signing_key(request.user)

    if key is None:
        raise ApiError('no_signing_key', "Aucune clé de signature enregistrée.")

    # --- 1. the passkey confirmation ---

    try:
        raw_id = credential['rawId']
    except (TypeError, KeyError) as exc:
        raise ApiError('invalid_credential', "Assertion passkey incomplète.") from exc

    passkey = Passkey.objects.filter(
        user=request.user, credential_id=base64url_to_bytes(raw_id)
    ).first()

    if passkey is None:
        raise ApiError('unknown_passkey', "Cette passkey n'est pas enregistrée.")

    try:
        verification = verify_authentication_response(
            credential=credential,
            expected_challenge=bytes(challenge.challenge),
            expected_rp_id=RP_ID,
            expected_origin=EXPECTED_ORIGINS,
            credential_public_key=bytes(passkey.public_key),
            credential_current_sign_count=passkey.sign_count,
            require_user_verification=settings.SIGNING_REQUIRE_USER_VERIFICATION,
        )
    except Exception as exc:
        challenge.consume()
        raise ApiError(
            'passkey_verification_failed',
            f"La confirmation par passkey a échoué : {exc}",
            status=403,
        ) from exc

    # Burn the challenge the moment it has served its purpose, whatever
    # happens to the RSA check below.
    challenge.consume()

    passkey.sign_count = verification.new_sign_count
    passkey.save(update_fields=['sign_count'])

    # --- 2. the RSA signature over the digest ---

    document.refresh_current_version()
    current_hash = current_document_hash(document)

    if (
        current_hash != challenge.document_hash
        or challenge.document_version_id != (
            document.current_version.id if document.current_version else None
        )
    ):
        raise ApiError(
            'document_changed',
            'Une nouvelle version a été déposée pendant la signature. '
            'Rechargez le document et recommencez.',
        )

    is_valid, reason = verify_signature(
        key.public_key_pem, challenge.document_hash, signature_b64
    )

    if not is_valid:
        raise ApiError('invalid_signature', reason, status=422)

    signature = Signature.objects.create(
        document=document,
        document_version=challenge.document_version,
        signer=request.user,
        signing_key=key,
        document_hash=challenge.document_hash,
        signature_value=signature_b64,
        challenge=challenge,
    )

    mark_signer_signed(document, request.user, when=signature.signed_at)
    recompute_document_status(document)
    document.refresh_from_db()

    return JsonResponse(
        {
            'signature': {
                'id': signature.id,
                'documentHash': signature.document_hash,
                'versionNumber': document.version_number,
                'algorithm': signature.algorithm,
                'signedAt': iso(signature.signed_at),
                'keyFingerprint': key.fingerprint,
            },
            'document': serialize_document(document, request.user, include_audit=True),
            'verification': serialize_verification(verify_document(document)),
        },
        status=201,
    )
