"""Short-lived in-process cache for read-heavy catalogue endpoints.

Cloud Run in asia-southeast1 talking to Cloud SQL in us-east4 pays a round
trip on every query. Catalogue, search and forecast rows change at most when
the daily R refresh lands, so serving a one-minute snapshot is accurate and
stops the home screen from repeating the same SELECT.
"""

from __future__ import annotations

import time
from typing import TypeVar

T = TypeVar("T")

_store: dict[str, tuple[float, object]] = {}


def get(key: str, ttl_seconds: float) -> object | None:
    row = _store.get(key)
    if row is None:
        return None
    stored_at, value = row
    if time.monotonic() - stored_at > ttl_seconds:
        _store.pop(key, None)
        return None
    return value


def put(key: str, value: object) -> None:
    _store[key] = (time.monotonic(), value)


def clear() -> None:
    _store.clear()
