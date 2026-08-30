"""CV inference service: adapter lifecycle and canonical resolution.

Two responsibilities, deliberately separated.

1. Own the ONNX adapter process-wide. The session is loaded once and reused; a
   missing or broken model package is a business-level unavailability, not a
   crash at import time, so the rest of the API keeps working without it.

2. Resolve model class labels to canonical seafood_item rows through
   cv_class_mapping. The model emits SF001..SF012 strings; the database owns
   the UUIDs. That join is the reason a better model can be dropped in without
   the public API changing shape, and the reason a scanned fish arrives at the
   same seafood_item_id that search, WWF, price and cooking all key off.
"""

from __future__ import annotations

import logging
import pathlib
import sys
import threading
import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import get_settings
from app.models import CvClassMapping, CvModelVersion, SeafoodItem

logger = logging.getLogger(__name__)

# The CV package lives at <repo>/cv/sukacv, beside backend/. Add it to the path
# so the backend imports it without a build step. If the team later installs it
# properly (pip install -e ../cv) this becomes a no-op.
_CV_ROOT = pathlib.Path(__file__).resolve().parents[3] / "cv"
if _CV_ROOT.is_dir() and str(_CV_ROOT) not in sys.path:
    sys.path.insert(0, str(_CV_ROOT))

_adapter: Any = None
_adapter_error: str | None = None
_lock = threading.Lock()


class CvUnavailable(RuntimeError):
    """Inference cannot be served. The API maps this to 503 MODEL_UNAVAILABLE."""


def _package_dir() -> pathlib.Path:
    path = pathlib.Path(get_settings().cv_package_dir)
    if not path.is_absolute():
        # Resolve relative to backend/, so the server behaves the same whatever
        # directory it was launched from.
        path = pathlib.Path(__file__).resolve().parents[2] / path
    return path


def get_adapter():
    """Return the process-wide adapter, loading it on first use.

    No model package is the normal state before the CV owner delivers one, so
    this raises CvUnavailable (-> 503) rather than preventing startup.
    """
    global _adapter, _adapter_error

    if _adapter is not None:
        return _adapter

    with _lock:
        if _adapter is not None:
            return _adapter
        if _adapter_error is not None:
            raise CvUnavailable(_adapter_error)

        package = _package_dir()
        try:
            from sukacv.adapter import CvAdapter, ModelUnavailableError
        except ImportError as exc:
            _adapter_error = (
                f"CV package is not importable ({exc}). Install the cv/ package "
                f"and its inference requirements."
            )
            raise CvUnavailable(_adapter_error) from exc

        settings = get_settings()
        try:
            _adapter = CvAdapter(
                package_dir=package,
                threshold=settings.cv_confidence_threshold,
                intra_op_threads=settings.cv_intra_op_threads,
            )
        except ModelUnavailableError as exc:
            _adapter_error = str(exc)
            logger.warning("CV adapter unavailable: %s", exc)
            raise CvUnavailable(str(exc)) from exc

        if "UNTRAINED" in _adapter.model_version.upper():
            logger.warning(
                "CV model '%s' is a DEV package: the classifier is UNTRAINED and "
                "its predictions are noise. Integration testing only.",
                _adapter.model_version,
            )
        else:
            logger.info("CV adapter loaded: %s from %s",
                        _adapter.model_version, package)
        return _adapter


def reset_adapter() -> None:
    """Drop the cached adapter. Used by tests and after a model swap."""
    global _adapter, _adapter_error
    with _lock:
        _adapter = None
        _adapter_error = None


async def active_model(session: AsyncSession) -> CvModelVersion | None:
    """The one active registered model, or None before a model is registered."""
    return await session.scalar(
        select(CvModelVersion).where(CvModelVersion.active.is_(True)).limit(1)
    )


async def resolve_candidates(
    session: AsyncSession,
    model_version: str,
    predictions: list[dict],
) -> list[dict]:
    """Model class labels -> canonical seafood rows, for THIS model version.

    A class the active model version has no mapping for is a configuration
    error, not something to paper over by guessing a fish. Raising is the
    correct outcome: the route turns it into a 503 and the app shows an
    unavailable state rather than naming the wrong species.
    """
    stmt = (
        select(CvClassMapping)
        .options(selectinload(CvClassMapping.seafood))
        .join(CvModelVersion,
              CvModelVersion.cv_model_version_id == CvClassMapping.cv_model_version_id)
        .where(CvModelVersion.version_name == model_version)
        .where(CvModelVersion.active.is_(True))
    )
    mappings = (await session.scalars(stmt)).all()
    by_label = {m.model_class_label: m for m in mappings}

    if not by_label:
        raise CvUnavailable(
            f"model '{model_version}' has no active cv_class_mapping rows. "
            f"Apply db/seed/06_cv_model_registration.sql (regenerate it with "
            f"`cd cv && python scripts/register_model.py`) before serving /identify."
        )

    missing = sorted({p["class_code"] for p in predictions
                      if p["class_code"] not in by_label})
    if missing:
        raise CvUnavailable(
            f"no canonical mapping for {missing} under active model "
            f"'{model_version}'. The class map and cv_class_mapping disagree, "
            f"which means the model and the database no longer describe the "
            f"same species."
        )

    out = []
    for p in predictions:
        item: SeafoodItem = by_label[p["class_code"]].seafood
        out.append({
            "rank": p["rank"],
            # The canonical key. Everything downstream — WWF, price, cooking,
            # favourites — joins on this, not on a name or a class code.
            "seafood_item_id": item.seafood_item_id,
            "code": item.code,
            "canonical_name_ms": item.canonical_name_ms,
            "display_name_en": item.display_name_en,
            "scientific_name": item.scientific_name,
            "confidence": p["confidence"],
        })
    return out


async def registered_class_map(session: AsyncSession) -> list[dict]:
    """The active model's class map, for /meta and for diagnostics."""
    model = await active_model(session)
    if model is None:
        return []
    stmt = (
        select(CvClassMapping)
        .options(selectinload(CvClassMapping.seafood))
        .where(CvClassMapping.cv_model_version_id == model.cv_model_version_id)
        .order_by(CvClassMapping.model_class_index)
    )
    return [
        {
            "class_index": m.model_class_index,
            "class_code": m.model_class_label,
            "seafood_item_id": str(m.seafood_item_id),
            "display_name_en": m.seafood.display_name_en,
        }
        for m in (await session.scalars(stmt)).all()
    ]
