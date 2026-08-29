"""Relying-party settings shared by the login and the signing ceremonies.

Both ceremonies must agree on the RP id and the accepted origins, so they read
them from one place rather than each computing their own from settings.
"""

from django.conf import settings


RP_ID = settings.PASSKEY_HOST

RP_NAME = settings.PASSKEY_RP_NAME

ORIGIN = f'https://{settings.PASSKEY_HOST}'

# The Android app presents its APK signing hash as the origin, not a URL.
EXPECTED_ORIGINS = [
    f'android:apk-key-hash:{settings.PASSKEY_APK_KEY_HASH}'
]
