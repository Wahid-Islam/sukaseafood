"""IUCN Red List lookups. Missing values stay unavailable — never invented."""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from urllib.parse import quote

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)

_V4 = "https://api.iucnredlist.org/api/v4"
_V3 = "https://apiv3.iucnredlist.org/api/v3"

IUCN_LABELS = {
    "LC": "Least Concern",
    "NT": "Near Threatened",
    "VU": "Vulnerable",
    "EN": "Endangered",
    "CR": "Critically Endangered",
    "EW": "Extinct in the Wild",
    "EX": "Extinct",
    "DD": "Data Deficient",
    "NE": "Not Evaluated",
}


@dataclass(frozen=True)
class IucnRecord:
    category: str | None
    label: str | None
    url: str
    population_trend: str | None


_CACHE: dict[str, tuple[datetime, IucnRecord | None]] = {}
_TTL = timedelta(hours=12)


def _scientific_parts(name: str) -> tuple[str, str] | None:
    bits = [p for p in name.strip().split() if p]
    if len(bits) < 2:
        return None
    return bits[0], bits[1]


def _label_for(code: str | None) -> str | None:
    if not code:
        return None
    return IUCN_LABELS.get(code.upper(), code)


def _from_cache(key: str) -> IucnRecord | None | str:
    row = _CACHE.get(key)
    if row is None:
        return "miss"
    stamp, value = row
    if datetime.now(timezone.utc) - stamp > _TTL:
        return "miss"
    return value


async def lookup_iucn(scientific_name: str) -> IucnRecord | None:
    """Return the latest global IUCN assessment, or None if unavailable."""
    key = get_settings().iucn_api_key.strip()
    scientific = " ".join(scientific_name.split())
    if not key or not scientific:
        return None
    if os.environ.get("PYTEST_CURRENT_TEST"):
        return None
    cached = _from_cache(scientific.lower())
    if cached != "miss":
        return cached  # type: ignore[return-value]

    record = await _fetch_v4(scientific, key)
    if record is None:
        record = await _fetch_v3(scientific, key)
    _CACHE[scientific.lower()] = (datetime.now(timezone.utc), record)
    return record


async def _fetch_v4(scientific: str, token: str) -> IucnRecord | None:
    parts = _scientific_parts(scientific)
    if parts is None:
        return None
    genus, species = parts
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
        "User-Agent": "SukaSeafood/1.0 (educational)",
    }
    timeout = httpx.Timeout(20.0)
    async with httpx.AsyncClient(timeout=timeout, headers=headers) as client:
        taxa = await _get_json(
            client,
            f"{_V4}/taxa/scientific_name",
            params={"genus_name": genus, "species_name": species},
        )
        latest = _latest_assessment(taxa)
        if latest is None:
            return None
        assessment_id = _as_int(
            latest.get("assessment_id") or latest.get("id")
        )
        detail: dict | None = None
        if assessment_id is not None:
            raw = await _get_json(client, f"{_V4}/assessment/{assessment_id}")
            if isinstance(raw, dict):
                detail = raw
        category = _v4_category(detail) if detail else None
        trend = _v4_trend(detail) if detail else None
        if not category:
            category = _assessment_category(latest)
        if not trend:
            trend = _assessment_trend(latest)
        url = _assessment_url(scientific, latest, detail)
        if not category and not trend:
            return None
        return IucnRecord(
            category=category,
            label=_label_for(category),
            url=url,
            population_trend=trend,
        )


async def _fetch_v3(scientific: str, token: str) -> IucnRecord | None:
    timeout = httpx.Timeout(20.0)
    params = {"token": token}
    slug = quote(scientific)
    async with httpx.AsyncClient(timeout=timeout) as client:
        data = await _get_json(
            client,
            f"{_V3}/species/{slug}",
            params=params,
        )
    if not isinstance(data, dict):
        return None
    rows = data.get("result")
    if not isinstance(rows, list) or not rows:
        return None
    row = rows[0] if isinstance(rows[0], dict) else None
    if row is None:
        return None
    category = str(row.get("category") or "").strip().upper() or None
    trend = str(row.get("population_trend") or "").strip() or None
    taxon_id = row.get("taxonid")
    url = f"https://www.iucnredlist.org/search?query={scientific.replace(' ', '%20')}"
    if taxon_id:
        url = f"https://www.iucnredlist.org/species/{taxon_id}"
    if not category and not trend:
        return None
    return IucnRecord(
        category=category,
        label=_label_for(category),
        url=url,
        population_trend=trend,
    )


async def _get_json(
    client: httpx.AsyncClient,
    url: str,
    params: dict[str, str] | None = None,
) -> dict | list | None:
    try:
        response = await client.get(url, params=params)
    except httpx.HTTPError as exc:
        logger.info("IUCN request failed for %s: %s", url.split("?")[0], exc)
        return None
    if response.status_code >= 400:
        logger.info("IUCN %s -> %s", url.split("?")[0], response.status_code)
        return None
    try:
        payload = response.json()
    except ValueError:
        return None
    return payload if isinstance(payload, (dict, list)) else None


def _latest_assessment(payload: dict | list | None) -> dict | None:
    assessments: list[dict] = []
    if isinstance(payload, dict):
        raw = payload.get("assessments") or payload.get("assessment")
        if isinstance(raw, list):
            assessments = [row for row in raw if isinstance(row, dict)]
        elif isinstance(raw, dict):
            assessments = [raw]
        elif payload.get("assessment_id") or payload.get("red_list_category_code"):
            assessments = [payload]
    elif isinstance(payload, list):
        assessments = [row for row in payload if isinstance(row, dict)]
    if not assessments:
        return None

    def sort_key(row: dict) -> tuple[int, int, int]:
        latest = 1 if row.get("latest") else 0
        global_scope = 1 if _is_global(row) else 0
        year = 0
        published = str(row.get("year_published") or "")
        if published.isdigit():
            year = int(published)
        return latest, global_scope, year

    assessments.sort(key=sort_key, reverse=True)
    return assessments[0]


def _is_global(row: dict) -> bool:
    scopes = row.get("scopes")
    if not isinstance(scopes, list) or not scopes:
        return True
    for scope in scopes:
        if isinstance(scope, dict):
            blob = " ".join(
                str(scope.get(key) or "")
                for key in ("code", "description", "name")
            ).lower()
            if "global" in blob or blob.strip() == "1":
                return True
        elif isinstance(scope, str) and "global" in scope.lower():
            return True
    return False


def _as_int(value: object) -> int | None:
    try:
        return int(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None


def _assessment_category(row: dict) -> str | None:
    return _v4_category(row) or _codeish(
        row.get("red_list_category_code") or row.get("code")
    )


def _assessment_trend(row: dict) -> str | None:
    return _v4_trend(row)


def _assessment_url(
    scientific: str, latest: dict, detail: dict | None
) -> str:
    for candidate in (
        (detail or {}).get("url"),
        latest.get("url"),
    ):
        if isinstance(candidate, str) and candidate.startswith("http"):
            return candidate
    sis = None
    if detail:
        taxon = detail.get("taxon")
        if isinstance(taxon, dict):
            sis = taxon.get("sis_id") or taxon.get("sis_taxon_id")
        sis = sis or detail.get("sis_taxon_id") or detail.get("sis_id")
    sis = sis or latest.get("sis_taxon_id") or latest.get("sis_id")
    sis_id = _as_int(sis)
    if sis_id is not None:
        return f"https://www.iucnredlist.org/species/{sis_id}"
    return (
        "https://www.iucnredlist.org/search?query="
        + quote(scientific)
    )


def _codeish(value: object) -> str | None:
    if isinstance(value, str) and value.strip():
        return value.strip().upper()
    return None


def _v4_category(detail: dict) -> str | None:
    raw = detail.get("red_list_category") or detail.get("red_list_category_code")
    if isinstance(raw, dict):
        code = raw.get("code") or raw.get("abbreviation")
        return _codeish(code)
    return _codeish(raw)


def _v4_trend(detail: dict) -> str | None:
    raw = detail.get("population_trend") or detail.get("populationTrend")
    if isinstance(raw, dict):
        desc = raw.get("description")
        if isinstance(desc, dict):
            text = desc.get("en") or next(iter(desc.values()), None)
            return str(text).strip() if text else None
        code = raw.get("code") or raw.get("value")
        return str(code).strip() if code else None
    if isinstance(raw, str) and raw.strip():
        return raw.strip()
    return None


async def apply_iucn(bio: "BiodiversityOut", scientific_name: str) -> "BiodiversityOut":
    """Overlay a live IUCN assessment when the token returns one."""
    from app.schemas import BiodiversityOut, BiodiversitySourceOut

    record = await lookup_iucn(scientific_name)
    if record is None:
        return bio
    sources: list[BiodiversitySourceOut] = []
    replaced = False
    for source in bio.sources:
        if source.key != "iucn_redlist":
            sources.append(source)
            continue
        replaced = True
        sources.append(
            source.model_copy(
                update={
                    "available": bool(record.category),
                    "url": record.url or source.url,
                    "unavailable_reason": None
                    if record.category
                    else source.unavailable_reason,
                }
            )
        )
    if not replaced:
        sources = list(bio.sources)
    return bio.model_copy(
        update={
            "iucn_category": record.category or bio.iucn_category,
            "iucn_label": record.label or bio.iucn_label,
            "iucn_url": record.url or bio.iucn_url,
            "population_trend": record.population_trend or bio.population_trend,
            "sources": sources,
        }
    )
