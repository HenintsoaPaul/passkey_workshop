"""RSA signature verification, and the digests it operates on.

The signature never covers the file itself: the phone hashes the document with
SHA-256 and signs that digest, so everything here works on a 32-byte digest.
`Prehashed` is what tells `cryptography` the caller already did the hashing.
"""

import base64
import binascii
import hashlib

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa, utils


SIGNATURE_ALGORITHM = 'RSASSA-PKCS1-v1_5-SHA256'

MINIMUM_KEY_SIZE = 2048


class InvalidPublicKey(Exception):
    """The submitted PEM is not a usable RSA public key."""


def sha256_of_file(file_field):
    """Hex SHA-256 of a `FileField`'s current content, read in chunks."""
    digest = hashlib.sha256()

    with file_field.open('rb') as handle:
        for chunk in handle.chunks():
            digest.update(chunk)

    return digest.hexdigest()


def load_public_key(pem):
    """Parse a PEM public key, rejecting anything that is not RSA-2048+."""
    try:
        key = serialization.load_pem_public_key(pem.encode('utf-8'))
    except (ValueError, TypeError, UnicodeEncodeError) as exc:
        raise InvalidPublicKey(f'PEM illisible : {exc}') from exc

    if not isinstance(key, rsa.RSAPublicKey):
        raise InvalidPublicKey('La clé doit être une clé RSA.')

    if key.key_size < MINIMUM_KEY_SIZE:
        raise InvalidPublicKey(
            f'La clé doit faire au moins {MINIMUM_KEY_SIZE} bits '
            f'(reçu {key.key_size}).'
        )

    return key


def public_key_fingerprint(pem):
    """SHA-256 of the DER encoding, so a key has one stable name everywhere."""
    key = load_public_key(pem)

    der = key.public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )

    return hashlib.sha256(der).hexdigest()


def key_algorithm_label(pem):
    return f'RSA-{load_public_key(pem).key_size}'


def verify_signature(public_key_pem, document_hash, signature_b64):
    """Check one RSA signature over a hex SHA-256 digest.

    Returns `(True, None)` when the signature holds, and `(False, reason)`
    otherwise. Verification failures are an expected outcome here — a tampered
    document is the case this whole feature exists to catch — so they come back
    as a value rather than an exception.
    """
    try:
        digest = binascii.unhexlify(document_hash)
    except (binascii.Error, TypeError, ValueError):
        return False, "L'empreinte signée n'est pas un SHA-256 hexadécimal."

    if len(digest) != hashes.SHA256.digest_size:
        return False, "L'empreinte signée ne fait pas 32 octets."

    try:
        signature = base64.b64decode(signature_b64, validate=True)
    except (binascii.Error, TypeError, ValueError):
        return False, "La signature n'est pas encodée en base64."

    try:
        key = load_public_key(public_key_pem)
    except InvalidPublicKey as exc:
        return False, str(exc)

    try:
        key.verify(
            signature,
            digest,
            padding.PKCS1v15(),
            utils.Prehashed(hashes.SHA256()),
        )
    except InvalidSignature:
        return False, "La signature ne correspond pas à l'empreinte."

    return True, None
