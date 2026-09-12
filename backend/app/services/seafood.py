"""Seafood domain services.

These functions translate the V3 Postgres model into the API contract the
Flutter client already consumes. The response shapes in app/schemas are
UNCHANGED — the client keeps sending `fish_id`; it is now `seafood_item.code`
(SF001…) rather than a hand-written slug.

Two product rules are enforced here rather than in the database, because they
are editorial decisions that must be visible in code review:

  * A species with no wwf_assessment row is UNDETERMINED. It is never given a
    default rating.
  * A price summary whose quality_status is not DISPLAYABLE is reported as
    "Insufficient data", never rendered as a number.
"""

from __future__ import annotations

import random
import re
import uuid

from sqlalchemy import func, inspect as sa_inspect, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import get_settings
from app.models import (
    BiodiversityOccurrence,
    BiodiversityProfile,
    CookingMethod,
    CookingSuitability,
    PricePeriodSummary,
    PriceTrendPoint,
    SeafoodAlias,
    SeafoodItem,
    WwfAssessment,
)
from app.models.enums import PeriodType, PriceQuality, SustainabilityRating
from app.schemas import (
    AliasOut,
    BiodiversityOut,
    BiodiversitySourceOut,
    CookingSuitabilityOut,
    IdentifyCandidate,
    IdentifyResponse,
    MethodRatingOut,
    OccurrenceOut,
    PriceContextOut,
    PricePointOut,
    SeafoodProfileOut,
    SeafoodSummaryOut,
    SustainabilityOut,
)

# --- presentation mappings ---------------------------------------------------

# The API has always spoken these labels; the enum speaks the WWF ones.
RATING_LABELS: dict[SustainabilityRating, str] = {
    SustainabilityRating.BEST_CHOICE: "GOOD CHOICE",
    SustainabilityRating.REDUCE: "REDUCE",
    SustainabilityRating.AVOID: "AVOID",
}

METHOD_LABELS: dict[str, str] = {
    "HOOK_AND_LINE": "Hook-and-line",
    "GILLNET": "Gillnet",
    "PURSE_SEINE": "Purse seine",
    "TRAWL": "Trawl",
    "AQUACULTURE": "Farmed",
}

UNDETERMINED = "UNDETERMINED"

WHY_IT_MATTERS: dict[SustainabilityRating, str] = {
    SustainabilityRating.BEST_CHOICE: (
        "Choosing better-rated seafood keeps pressure off stocks that are "
        "already struggling, and it is usually the cheaper option too."
    ),
    SustainabilityRating.REDUCE: (
        "Buying this less often gives the stock room to recover while keeping "
        "the fishery viable for the people who depend on it."
    ),
    SustainabilityRating.AVOID: (
        "This species is under real pressure. A better-rated fish at the same "
        "stall will usually cook the same way for less money."
    ),
}

UNDETERMINED_EXPLANATION = (
    "WWF Save Our Seafood guidance is ambiguous for this species: the rating "
    "depends on production method and origin, and neither is reliably labelled "
    "at point of sale. Returning UNDETERMINED rather than guessing."
)

UNDETERMINED_WHY = (
    "When sustainability is unclear, ask the seller about origin and method, or "
    "pick a species with a documented rating."
)

# Accepted spellings for cooking methods, mapped to canonical codes. The client
# has historically sent 'grilling' and 'pan-fry'; those keep working.
COOKING_ALIASES: dict[str, str] = {
    "grill": "GRILL", "grilling": "GRILL", "grilled": "GRILL", "panggang": "GRILL",
    "steam": "STEAM", "steaming": "STEAM", "steamed": "STEAM", "kukus": "STEAM",
    "fry": "FRY", "frying": "FRY", "fried": "FRY", "pan-fry": "FRY",
    "pan fry": "FRY", "panfry": "FRY", "deep-fry": "FRY", "stir-fry": "FRY",
    "goreng": "FRY",
    "curry": "CURRY", "kari": "CURRY", "gulai": "CURRY",
    "soup": "SOUP", "sup": "SOUP",
    "bake": "BAKE", "baking": "BAKE", "baked": "BAKE", "bakar": "BAKE",
    "raw": "RAW", "mentah": "RAW",
}

PRICE_DISCLAIMER = (
    "Observed price context from OpenDOSM PriceCatcher — "
    "not a nationally representative average."
)


def _assessment_loader():
    """Eager-load a species' WWF assessments AND their snapshots.

    `_display_assessments()` reads `snapshot.retrieved_at`. Without loading the snapshot up front, that read is
    lazy IO in a sync context and SQLAlchemy raises MissingGreenlet — so this
    chain is load-bearing, not an optimisation.
    """
    return selectinload(SeafoodItem.wwf_assessments).selectinload(
        WwfAssessment.snapshot
    )


def _fish_type(item: SeafoodItem) -> str:
    """Shopper-facing type label from the V3 fish_type column."""
    return item.fish_type or item.family or "Seafood"


def _image_url(item: SeafoodItem) -> str | None:
    """Return a URL the client can actually load, or None.

    Firebase Storage paths derived from `code` 404'd in production for every
    species. Emitting those URLs made catalogue cards look broken. A missing
    photo degrades to a placeholder; a 404 JSON body does not.
    """
    if item.primary_image_url:
        return item.primary_image_url
    return None


# --- reads -------------------------------------------------------------------


def _cooking_loader():
    """Eager-load cooking scores so catalogue cards can filter by method."""
    return selectinload(SeafoodItem.cooking_suitability).selectinload(
        CookingSuitability.method
    )


async def list_seafood(session: AsyncSession) -> list[SeafoodItem]:
    """All active supported species, with their WWF assessment preloaded."""
    stmt = (
        select(SeafoodItem)
        .where(SeafoodItem.active.is_(True))
        .options(_assessment_loader(), _cooking_loader())
        .order_by(SeafoodItem.code)
    )
    return list(await session.scalars(stmt))


async def get_seafood_by_id(
    session: AsyncSession,
    fish_id: str,
    *,
    relations: bool = True,
) -> SeafoodItem | None:
    """Resolve a seafood identifier to a canonical record.

    Accepts either form of the identifier:

      * `code`            — 'SF001', the readable public identifier used in
                            URLs and by anyone typing one by hand
      * `seafood_item_id` — the canonical UUID, which is what /identify
                            returns and what every table joins on

    Both are needed. The scanner hands the client a UUID, and the client then
    asks for that fish's profile, price and cooking; if this only understood
    codes, the whole scan → confirm → decide journey would break at the first
    step after confirmation.
    """
    identifier = fish_id.strip()

    try:
        as_uuid = uuid.UUID(identifier)
    except (ValueError, AttributeError):
        as_uuid = None

    predicate = (
        SeafoodItem.seafood_item_id == as_uuid
        if as_uuid is not None
        else func.upper(SeafoodItem.code) == identifier.upper()
    )

    stmt = (
        select(SeafoodItem)
        .where(predicate)
    )
    if relations:
        stmt = stmt.options(
            selectinload(SeafoodItem.aliases),
            _assessment_loader(),
            selectinload(SeafoodItem.cooking_suitability).selectinload(
                CookingSuitability.method
            ),
            selectinload(SeafoodItem.biodiversity_profile),
            selectinload(SeafoodItem.biodiversity_occurrences),
        )
    return await session.scalar(stmt)


async def search_seafood(session: AsyncSession, query: str) -> list[SeafoodItem]:
    """Search by Malay name, English name, scientific name, or alias.

    Shoppers type any of the three catalogue names. Aliases still catch
    spellings like "ikan kembung" that are not the canonical string.
    """
    q = query.strip().lower()
    if not q:
        return []

    pattern = f"%{q}%"
    alias = func.lower(func.trim(SeafoodAlias.alias_name))
    malay = func.lower(func.trim(SeafoodItem.canonical_name_ms))
    english = func.lower(func.trim(SeafoodItem.display_name_en))
    scientific = func.lower(func.trim(SeafoodItem.scientific_name))
    stmt = (
        select(
            SeafoodItem,
            func.min(
                func.least(
                    func.abs(func.length(SeafoodItem.canonical_name_ms) - len(q)),
                    func.abs(func.length(SeafoodItem.display_name_en) - len(q)),
                    func.abs(func.length(SeafoodItem.scientific_name) - len(q)),
                    func.abs(
                        func.coalesce(func.length(SeafoodAlias.alias_name), 999)
                        - len(q)
                    ),
                )
            ).label("best"),
        )
        .outerjoin(
            SeafoodAlias,
            SeafoodAlias.seafood_item_id == SeafoodItem.seafood_item_id,
        )
        .where(SeafoodItem.active.is_(True))
        .where(
            or_(
                malay.like(pattern),
                english.like(pattern),
                scientific.like(pattern),
                alias.like(pattern),
            )
        )
        .options(_assessment_loader(), _cooking_loader())
        .group_by(SeafoodItem.seafood_item_id)
        .order_by("best")
    )
    return [row[0] for row in (await session.execute(stmt)).all()]


async def recommend_for_cooking(session: AsyncSession, method: str) -> list[SeafoodItem]:
    """Species best suited to a cooking method, highest score first."""
    code = COOKING_ALIASES.get(method.strip().lower(), method.strip().upper())

    stmt = (
        select(SeafoodItem)
        .join(
            CookingSuitability,
            CookingSuitability.seafood_item_id == SeafoodItem.seafood_item_id,
        )
        .join(
            CookingMethod,
            CookingMethod.cooking_method_id == CookingSuitability.cooking_method_id,
        )
        .where(CookingMethod.code == code)
        .where(SeafoodItem.active.is_(True))
        .options(_assessment_loader(), _cooking_loader())
        .order_by(CookingSuitability.suitability_score.desc(), SeafoodItem.code)
    )
    return list(await session.scalars(stmt))


# --- mapping to the API contract ---------------------------------------------


def _display_assessments(item: SeafoodItem) -> list[WwfAssessment]:
    """Latest-snapshot assessments, one per catch method, better rating first."""
    rows = list(item.wwf_assessments or [])
    if not rows:
        return []

    def retrieved(row: WwfAssessment):
        return row.snapshot.retrieved_at if row.snapshot else None

    latest = max((retrieved(row) for row in rows), default=None)
    if latest is not None:
        rows = [row for row in rows if retrieved(row) == latest] or rows

    seen: set[str] = set()
    unique: list[WwfAssessment] = []
    for row in rows:
        key = (
            row.production_method_code
            or row.production_method_raw
            or row.source_record_key
            or ""
        ).upper()
        if key in seen:
            continue
        seen.add(key)
        unique.append(row)

    rank = {"GOOD CHOICE": 0, "REDUCE": 1, "AVOID": 2}
    unique.sort(
        key=lambda row: (
            rank.get(RATING_LABELS[row.rating], 9),
            _method_label(row),
        )
    )
    return unique


def _method_label(assessment: WwfAssessment) -> str:
    code = (assessment.production_method_code or "").upper()
    if code in METHOD_LABELS:
        return METHOD_LABELS[code]
    raw = (assessment.production_method_raw or "").strip()
    cleaned = re.sub(r"\s*\([^)]*\)\s*", "", raw).strip()
    return cleaned or raw or "Unknown method"


def _to_method_rating(assessment: WwfAssessment) -> MethodRatingOut:
    return MethodRatingOut(
        classification=RATING_LABELS[assessment.rating],
        production_method=_method_label(assessment),
        production_method_code=(assessment.production_method_code or "OTHER"),
        origin=assessment.origin_raw or "Malaysia",
        explanation=_applies_to(assessment),
    )


def _suitable_methods(item: SeafoodItem) -> list[str]:
    """Cooking methods with a curated score of 4 or 5."""
    if "cooking_suitability" in sa_inspect(item).unloaded:
        return []
    methods: list[str] = []
    for row in item.cooking_suitability:
        if (row.suitability_score or 0) < 4:
            continue
        code = (row.method.code if row.method is not None else "").lower()
        if code and code not in methods:
            methods.append(code)
    return methods


def to_summary(item: SeafoodItem) -> SeafoodSummaryOut:
    """Compact card for search results and lists."""
    rows = _display_assessments(item)
    labels = {RATING_LABELS[row.rating] for row in rows}
    classification = next(iter(labels)) if len(labels) == 1 else UNDETERMINED
    return SeafoodSummaryOut(
        fish_id=item.code,
        scientific_name=item.scientific_name,
        primary_common_name=item.canonical_name_ms,
        display_name_en=item.display_name_en,
        fish_type=_fish_type(item),
        image_url=_image_url(item),
        classification=classification,
        description=(item.description or "").strip(),
        suitable_methods=_suitable_methods(item),
    )


def to_sustainability(item: SeafoodItem) -> SustainabilityOut:
    """WWF payload, including the honest 'we don't know' case."""
    rows = _display_assessments(item)
    method_ratings = [_to_method_rating(row) for row in rows]

    if not rows:
        return SustainabilityOut(
            classification=UNDETERMINED,
            origin="Varies — confirm at purchase",
            production_method="Wild-caught or farmed (confirm at purchase)",
            explanation=UNDETERMINED_EXPLANATION,
            why_it_matters=UNDETERMINED_WHY,
            source_name="WWF Save Our Seafood",
            source_url="https://www.saveourseafood.my/",
            verified=False,
            assessments=[],
        )

    labels = {RATING_LABELS[row.rating] for row in rows}
    if len(labels) > 1:
        context = (rows[0].context or "").strip()
        return SustainabilityOut(
            classification=UNDETERMINED,
            origin="Varies — confirm catch method at purchase",
            production_method=" / ".join(
                _method_label(row) for row in rows
            ),
            explanation="Rating varies by catch method.",
            why_it_matters=context or UNDETERMINED_WHY,
            source_name="WWF Save Our Seafood",
            source_url="https://www.saveourseafood.my/",
            verified=True,
            assessments=method_ratings,
        )

    assessment = rows[0]
    applies = _applies_to(assessment)
    context = (assessment.context or "").strip()
    why = context if context and not context.startswith("Applies to") else WHY_IT_MATTERS[
        assessment.rating
    ]
    return SustainabilityOut(
        classification=RATING_LABELS[assessment.rating],
        origin=assessment.origin_raw or "Malaysia",
        production_method=assessment.production_method_raw or "",
        explanation=applies,
        why_it_matters=why,
        source_name="WWF Save Our Seafood",
        source_url="https://www.saveourseafood.my/",
        verified=True,
        assessments=method_ratings,
    )


def _applies_to(assessment: WwfAssessment) -> str:
    """Short applicability line for the classification card."""
    stored = (assessment.context or "").strip()
    if stored.startswith("Applies to"):
        return stored
    name = assessment.common_name_raw or "this species"
    origin = assessment.origin_raw or "the listed origin"
    method = assessment.production_method_raw or "the listed method"
    return f"Applies to {origin} {name} taken by {method}."


def _biodiversity_sources(
    profile: BiodiversityProfile | None,
    occurrences: list[BiodiversityOccurrence],
) -> list[BiodiversitySourceOut]:
    fishbase_url = (profile.fishbase_url if profile else None) or ""
    iucn_url = (profile.iucn_url if profile else None) or ""
    has_habitat = bool(profile and (profile.habitat_group or profile.ecological_role))
    has_iucn = bool(profile and profile.iucn_category)
    return [
        BiodiversitySourceOut(
            key="fishbase",
            name="FishBase",
            available=has_habitat,
            url=fishbase_url,
            unavailable_reason=None
            if has_habitat
            else "No FishBase extract is on file for this species.",
        ),
        BiodiversitySourceOut(
            key="obis",
            name="OBIS",
            available=bool(occurrences),
            url="https://obis.org",
            unavailable_reason=None
            if occurrences
            else "No OBIS occurrence points are on file for this species.",
        ),
        BiodiversitySourceOut(
            key="iucn_redlist",
            name="IUCN Red List of Threatened Species",
            available=has_iucn,
            url=iucn_url or "https://www.iucnredlist.org",
            unavailable_reason=None
            if has_iucn
            else "No IUCN category is on file for this species.",
        ),
        BiodiversitySourceOut(
            key="mybis",
            name="MyBIS",
            available=False,
            url="https://www.mybis.gov.my",
            unavailable_reason=(
                "MyBIS has no public API on file. National status stays "
                "unavailable. Local names come from the catalogue aliases."
            ),
        ),
        BiodiversitySourceOut(
            key="reef_check",
            name="Reef Check",
            available=False,
            url="https://www.reefcheck.org.my",
            unavailable_reason=(
                "No public Reef Check extract is on file. Local survey "
                "metrics are not invented."
            ),
        ),
    ]


def to_biodiversity(
    item: SeafoodItem, sustainability: SustainabilityOut
) -> BiodiversityOut:
    """Retrieved FishBase / OBIS / IUCN facts. Missing fields stay empty."""
    del sustainability  # WWF ratings stay on the sustainability payload.
    family = (item.family or "").strip() or None
    taxonomic = (item.taxonomic_level or "").strip() or None
    profile = item.biodiversity_profile
    occurrences = list(item.biodiversity_occurrences or [])
    sources = _biodiversity_sources(profile, occurrences)

    if profile is None:
        return BiodiversityOut(
            family=family,
            habitat_group=None,
            taxonomic_level=taxonomic,
            ecosystem_note=None,
            available=False,
            source_name="SukaSeafood catalogue",
            source_url="",
            sources=sources,
            unavailable_reason=(
                "No independent biodiversity extract is on file for this "
                "species. Habitat, depth, IUCN status and map points are "
                "not invented."
            ),
        )

    depth_shallow = (
        float(profile.depth_shallow_m)
        if profile.depth_shallow_m is not None
        else None
    )
    depth_deep = (
        float(profile.depth_deep_m) if profile.depth_deep_m is not None else None
    )
    role = (profile.ecological_role or "").strip() or None
    occ_out = [
        OccurrenceOut(
            latitude=float(row.latitude),
            longitude=float(row.longitude),
            country=row.country,
            locality=row.locality,
            event_date=row.event_date.isoformat() if row.event_date else None,
        )
        for row in occurrences
    ]
    cited = [s.name for s in sources if s.available]
    return BiodiversityOut(
        family=family,
        habitat_group=(profile.habitat_group or "").strip() or None,
        taxonomic_level=taxonomic,
        ecosystem_note=role,
        depth_shallow_m=depth_shallow,
        depth_deep_m=depth_deep,
        ecological_role=role,
        iucn_category=(profile.iucn_category or "").strip() or None,
        iucn_label=(profile.iucn_label or "").strip() or None,
        iucn_url=(profile.iucn_url or "").strip() or None,
        fishbase_url=(profile.fishbase_url or "").strip() or None,
        occurrences=occ_out,
        sources=sources,
        available=True,
        source_name=" · ".join(cited) if cited else "FishBase · OBIS · IUCN Red List",
        source_url=(profile.fishbase_url or "").strip(),
        unavailable_reason=None,
    )


async def build_profile(session: AsyncSession, item: SeafoodItem) -> SeafoodProfileOut:
    """Full decision-journey profile for one species."""
    cooking = sorted(
        item.cooking_suitability,
        key=lambda c: (-(c.suitability_score or 0), c.method.code),
    )
    sustainability = to_sustainability(item)

    return SeafoodProfileOut(
        fish_id=item.code,
        scientific_name=item.scientific_name,
        primary_common_name=item.canonical_name_ms,
        display_name_en=item.display_name_en,
        fish_type=_fish_type(item),
        family=(item.family or "").strip() or None,
        common_in="Malaysia",
        market_availability="Year-round",
        about=item.description or item.notes or "",
        image_url=_image_url(item),
        aliases=[
            AliasOut(alias=a.alias_name, language=a.language_code or "ms")
            for a in sorted(item.aliases, key=lambda a: a.alias_name)
        ],
        sustainability=sustainability,
        biodiversity=to_biodiversity(item, sustainability),
        cooking=[
            CookingSuitabilityOut(
                method=c.method.code.lower(),
                # The API contract is a 0-1 float; the database stores 1-5.
                suitability_score=round((c.suitability_score or 0) / 5, 2),
                rationale=c.reason_en,
                verified=c.source_snapshot_id is not None,
            )
            for c in cooking
        ],
    )


async def get_price_context(session: AsyncSession, fish_id: str) -> PriceContextOut:
    """Observed price context for one species.

    V3 keys derived price outputs by seafood_item_id (not PriceCatcher item
    code). Anything not marked DISPLAYABLE is reported as insufficient data.
    """
    item = await get_seafood_by_id(session, fish_id)
    if item is None:
        return PriceContextOut(
            fish_id=fish_id,
            latest_price_rm_per_kg=None,
            status="Unknown species",
            change_vs_recent_pct=None,
            history=[],
            disclaimer=PRICE_DISCLAIMER,
        )

    summary = await session.scalar(
        select(PricePeriodSummary)
        .where(PricePeriodSummary.seafood_item_id == item.seafood_item_id)
        .where(PricePeriodSummary.period_type == PeriodType.MONTH)
        .order_by(PricePeriodSummary.period_end.desc())
        .limit(1)
    )

    if summary is None or summary.quality_status != PriceQuality.DISPLAYABLE:
        return PriceContextOut(
            fish_id=item.code,
            latest_price_rm_per_kg=None,
            status="Insufficient data",
            change_vs_recent_pct=None,
            history=[],
            disclaimer=PRICE_DISCLAIMER,
        )

    trend = list(
        await session.scalars(
            select(PriceTrendPoint)
            .where(PriceTrendPoint.seafood_item_id == item.seafood_item_id)
            .where(PriceTrendPoint.location_id == summary.location_id)
            .where(PriceTrendPoint.quality_status == PriceQuality.DISPLAYABLE)
            .order_by(PriceTrendPoint.week_start.desc())
            .limit(12)
        )
    )
    trend.reverse()

    change_pct = None
    if len(trend) >= 2 and trend[-2].weekly_median_price:
        prev = float(trend[-2].weekly_median_price)
        if prev:
            change_pct = round(
                (float(trend[-1].weekly_median_price) - prev) / prev * 100,
                1,
            )

    latest = (
        float(trend[-1].weekly_median_price)
        if trend
        else float(summary.median_price)
    )

    return PriceContextOut(
        fish_id=item.code,
        latest_price_rm_per_kg=latest,
        status="Observed",
        change_vs_recent_pct=change_pct,
        history=[
            PricePointOut(
                observed_date=p.week_start,
                price_rm_per_kg=float(p.weekly_median_price),
                premise_state="",
                premise_type="",
                note=f"Weekly median of {p.observation_count} observations",
            )
            for p in trend
        ],
        disclaimer=PRICE_DISCLAIMER,
    )


# --- mock CV -----------------------------------------------------------------


async def mock_identify(session: AsyncSession, hint: str | None = None) -> IdentifyResponse:
    """Stand-in for the Fish-Vista adapter.

    Only species with supports_cv are eligible, so the mock cannot return a
    prediction the real model will never be able to make.
    """
    stmt = (
        select(SeafoodItem)
        .where(SeafoodItem.active.is_(True), SeafoodItem.supports_cv.is_(True))
        .order_by(SeafoodItem.code)
    )
    candidates = list(await session.scalars(stmt))

    if not candidates:
        raise ValueError(
            "No CV-supported species in the database. Apply the schema and seed "
            "(backend/db/apply.sh) before calling /identify."
        )

    top = None
    if hint:
        matches = await search_seafood(session, hint)
        top = next((m for m in matches if m.supports_cv), None)
    if top is None:
        top = random.choice(candidates)  # noqa: S311 - mock adapter, not security

    others = [c for c in candidates if c.seafood_item_id != top.seafood_item_id][:2]

    def candidate(item: SeafoodItem, confidence: float) -> IdentifyCandidate:
        return IdentifyCandidate(
            fish_id=item.code,
            primary_common_name=item.canonical_name_ms,
            scientific_name=item.scientific_name,
            confidence=confidence,
        )

    return IdentifyResponse(
        model_version=get_settings().identify_model_version,
        top_prediction=candidate(top, 0.82),
        alternatives=[candidate(o, c) for o, c in zip(others, (0.11, 0.07))],
        requires_user_confirmation=True,
        is_mock=True,
    )


__all__ = [
    "build_profile",
    "get_price_context",
    "get_seafood_by_id",
    "list_seafood",
    "mock_identify",
    "recommend_for_cooking",
    "search_seafood",
    "to_summary",
    "to_sustainability",
]
