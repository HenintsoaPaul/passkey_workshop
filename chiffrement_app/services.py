"""Document state and the global verification described in §2.5 of the TP."""

from django.utils import timezone

from .crypto import sha256_of_file, verify_signature
from .models import Document, DocumentSigner, SignatureLog


def recompute_document_status(document, save=True):
    """Derive a document's state from the signatures actually recorded.

    Single source of truth for the three states the spec names, so the API and
    the web views cannot drift apart. Archived documents are terminal and are
    left alone.
    """
    if document.status == 'archived':
        return document.status

    signers = document.signers.all()

    if not signers:
        status = 'draft'
    else:
        signed = document.signatures.values_list('signer_id', flat=True)
        signed_count = sum(1 for signer in signers if signer.user_id in set(signed))

        if signed_count == 0:
            status = 'pending'
        elif signed_count < len(signers):
            status = 'partially_signed'
        else:
            status = 'fully_signed'

    if status != document.status:
        document.status = status

        if save:
            # update_fields keeps this off the file-hashing path in
            # Document.save(), which re-reads the whole file.
            Document.objects.filter(pk=document.pk).update(
                status=status, updated_at=timezone.now()
            )

    return status


def current_document_hash(document):
    """Hash the file as it stands on disk right now.

    Not `document.file_hash`: the point of the check is to catch the case where
    the stored hash and the bytes no longer agree.
    """
    try:
        return sha256_of_file(document.file)
    except (FileNotFoundError, ValueError, OSError):
        return None


def verify_document(document):
    """Run the four conditions of §2.5 and report each one separately.

    A caller needs to know *which* condition failed — "incomplete" and
    "tampered with" are very different answers — so the report keeps the checks
    apart instead of collapsing them into one boolean.
    """
    signers = list(document.signers.select_related('user__profile'))
    signatures = list(
        document.signatures.select_related('signer__profile', 'signing_key')
    )
    by_signer = {signature.signer_id: signature for signature in signatures}

    current_hash = current_document_hash(document)

    signature_reports = []

    for signature in signatures:
        is_valid, reason = verify_signature(
            signature.signing_key.public_key_pem,
            signature.document_hash,
            signature.signature_value,
        )

        if is_valid and signature.signing_key.revoked_at is not None:
            is_valid = False
            reason = 'La clé utilisée a été révoquée.'

        signature_reports.append({
            'signer': signature.signer.username,
            'signer_name': _display_name(signature.signer),
            'signed_at': signature.signed_at,
            'algorithm': signature.algorithm,
            'document_hash': signature.document_hash,
            'key_fingerprint': signature.signing_key.fingerprint,
            'is_valid': is_valid,
            'reason': reason,
        })

    missing = [
        _display_name(signer.user)
        for signer in signers
        if signer.user_id not in by_signer
    ]

    signed_hashes = {signature.document_hash for signature in signatures}

    all_present = bool(signers) and not missing
    all_valid = bool(signatures) and all(r['is_valid'] for r in signature_reports)
    same_version = len(signed_hashes) <= 1
    hash_matches = bool(signatures) and signed_hashes == {current_hash}

    checks = [
        {
            'code': 'signatures_present',
            'label': 'Toutes les signatures obligatoires sont présentes',
            'passed': all_present,
            'detail': (
                'Signataire(s) manquant(s) : ' + ', '.join(missing)
                if missing
                else ('Aucun signataire affecté.' if not signers else None)
            ),
        },
        {
            'code': 'signatures_valid',
            'label': 'Toutes les signatures sont valides',
            'passed': all_valid,
            'detail': _first_failure(signature_reports),
        },
        {
            'code': 'same_version',
            'label': 'Toutes les signatures portent sur la même version',
            'passed': same_version,
            'detail': (
                f'{len(signed_hashes)} empreintes différentes signées.'
                if not same_version
                else None
            ),
        },
        {
            'code': 'hash_matches',
            'label': "L'empreinte actuelle correspond à l'empreinte signée",
            'passed': hash_matches,
            'detail': (
                'Le fichier est introuvable ou illisible.'
                if current_hash is None
                else (
                    'Le document a été modifié depuis sa signature.'
                    if signatures and not hash_matches
                    else None
                )
            ),
        },
    ]

    # "Not signed yet" and "signed but broken" are different answers and must
    # not collapse into one: only a cryptographic failure makes a document
    # invalid, a merely unfinished one is incomplete.
    compromised = (
        any(not report['is_valid'] for report in signature_reports)
        or not same_version
        or (signatures and not hash_matches)
    )

    if all(check['passed'] for check in checks):
        verdict = 'valid'
    elif compromised:
        verdict = 'invalid'
    else:
        verdict = 'incomplete'

    return {
        'document_id': document.id,
        'title': document.title,
        'status': document.status,
        'verdict': verdict,
        'current_hash': current_hash,
        'stored_hash': document.file_hash,
        'signed_count': len(signatures),
        'required_count': len(signers),
        'checks': checks,
        'signatures': signature_reports,
        'missing_signers': missing,
    }


def _first_failure(signature_reports):
    for report in signature_reports:
        if not report['is_valid']:
            return f"{report['signer_name']} : {report['reason']}"

    return None


def _display_name(user):
    profile = getattr(user, 'profile', None)

    if profile and profile.name:
        return profile.name

    return user.get_full_name() or user.username


def mark_signer_signed(document, user, when=None):
    """Move the signer row to `signed` and log it."""
    signer = DocumentSigner.objects.filter(document=document, user=user).first()

    if signer is None:
        return None

    signer.signature_status = 'signed'
    signer.signature_date = when or timezone.now()
    signer.save(update_fields=['signature_status', 'signature_date', 'updated_at'])

    SignatureLog.objects.create(
        document=document,
        action='signed',
        user=user,
        details=(
            f'Signature RSA de {_display_name(user)} enregistrée '
            f'après confirmation par passkey'
        ),
    )

    return signer
