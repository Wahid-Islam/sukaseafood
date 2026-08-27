"""Firebase integration — hosting and object storage only.

Division of responsibility, deliberately strict:

    PostgreSQL   owns every fact the app displays. Species, aliases, WWF
                 ratings, prices, cooking guidance, provenance. It is the
                 system of record and the only thing the API queries.

    Firebase     owns bytes and delivery. Hosting serves the Flutter web build
                 and rewrites /api/** to the FastAPI service; Storage holds
                 seafood photography and CV reference imagery.

No domain data is ever written to Firebase. The reason is auditability: a WWF
rating shown to a user has to be traceable to a dated source snapshot, and that
trail only exists in Postgres.

Because of that split, `seafood_item` has no image_url column. An image's
location is DERIVED from the species code:

    SF001  ->  gs://<bucket>/seafood/SF001.jpg

so replacing artwork is a file upload, never a database migration, and a
missing file degrades to `None` rather than a broken link in the app.

The Firebase Admin SDK is optional at runtime. Without credentials this module
still returns public download URLs (Storage objects that are world-readable
need no SDK), so local development and CI never require a service account.
"""

from __future__ import annotations

import logging
from functools import lru_cache
from urllib.parse import quote

from app.config import get_settings

logger = logging.getLogger(__name__)

_admin_app = None
_admin_available: bool | None = None


def _try_init_admin() -> bool:
    """Initialise firebase-admin once, if it is installed and configured.

    Returns False (and logs at debug level) when the SDK is absent or no
    credentials are present. This is an expected state, not an error: signed
    URLs and uploads are unavailable, public reads still work.
    """
    global _admin_app, _admin_available

    if _admin_available is not None:
        return _admin_available

    settings = get_settings()
    if not settings.firebase_enabled or not settings.firebase_storage_bucket:
        _admin_available = False
        return False

    try:
        import firebase_admin
        from firebase_admin import credentials
    except ImportError:
        logger.debug("firebase-admin not installed; using public Storage URLs only.")
        _admin_available = False
        return False

    try:
        if firebase_admin._apps:  # noqa: SLF001 - the SDK's only presence check
            _admin_app = firebase_admin.get_app()
        else:
            cred = (
                credentials.Certificate(settings.firebase_credentials_path)
                if settings.firebase_credentials_path
                # Application Default Credentials: how this authenticates on
                # Cloud Run / GCP without shipping a key file.
                else credentials.ApplicationDefault()
            )
            _admin_app = firebase_admin.initialize_app(
                cred,
                {
                    "projectId": settings.firebase_project_id,
                    "storageBucket": settings.firebase_storage_bucket,
                },
            )
        _admin_available = True
    except Exception as exc:  # noqa: BLE001 - never block startup on Firebase
        logger.warning("Firebase Admin init failed (%s); using public URLs only.", exc)
        _admin_available = False

    return _admin_available


def storage_object_path(code: str, extension: str = "jpg") -> str:
    """Storage path for a species image, derived from its canonical code."""
    settings = get_settings()
    return f"{settings.firebase_image_prefix}/{code.upper()}.{extension}"


@lru_cache(maxsize=256)
def image_url(code: str | None, extension: str = "jpg") -> str | None:
    """Public download URL for a species image, or None if Storage is unconfigured.

    Returns a URL without checking that the object exists — a HEAD request per
    species would add latency to every list response, and the client already
    handles a failed image load. Configure the bucket's objects as publicly
    readable, or swap this for `signed_image_url` if they must stay private.
    """
    settings = get_settings()
    if not code or not settings.firebase_enabled or not settings.firebase_storage_bucket:
        return None

    object_path = quote(storage_object_path(code, extension), safe="")
    return (
        f"https://firebasestorage.googleapis.com/v0/b/"
        f"{settings.firebase_storage_bucket}/o/{object_path}?alt=media"
    )


def signed_image_url(code: str, extension: str = "jpg", ttl_seconds: int = 3600) -> str | None:
    """Time-limited URL for a private bucket. Requires firebase-admin + credentials."""
    if not _try_init_admin():
        return None

    try:
        from datetime import timedelta

        from firebase_admin import storage

        bucket = storage.bucket(app=_admin_app)
        blob = bucket.blob(storage_object_path(code, extension))
        if not blob.exists():
            return None
        return blob.generate_signed_url(expiration=timedelta(seconds=ttl_seconds))
    except Exception as exc:  # noqa: BLE001
        logger.warning("Signed URL generation failed for %s: %s", code, exc)
        return None


def status() -> dict[str, object]:
    """Firebase configuration state, surfaced by the health endpoint."""
    settings = get_settings()
    return {
        "enabled": settings.firebase_enabled,
        "project_id": settings.firebase_project_id or None,
        "storage_bucket": settings.firebase_storage_bucket or None,
        "admin_sdk": "available" if _try_init_admin() else "unavailable (public URLs only)",
    }
