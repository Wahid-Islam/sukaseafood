"""Seafood domain services.

These functions translate the 17-table Postgres model into the API contract the
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

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import firebase
from app.config import get_settings
from app.models import (
    CookingMethod,
    CookingSuitability,
    PriceItemMapping,
    PriceSummary,
    PriceTrendPoint,
    SeafoodAlias,
    SeafoodItem,
    SupplyLandingPoint,
    WwfAssessment,
)
from app.models.enums import PriceQuality, SustainabilityRating
from app.schemas import (
    AliasOut,
    CookingSuitabilityOut,
    IdentifyCandidate,
    IdentifyResponse,
    PriceContextOut,
    PricePointOut,
    SeafoodProfileOut,
    SeafoodSummaryOut,
    SupplyContextOut,
    SustainabilityOut,
)

# --- presentation mappings ---------------------------------------------------

# The API has always spoken these labels; the enum speaks the WWF ones.
RATING_LABELS: dict[SustainabilityRating, str] = {
    SustainabilityRating.BEST_CHOICE: "GOOD CHOICE",
    SustainabilityRating.REDUCE: "REDUCE",
    SustainabilityRating.AVOID: "AVOID",
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

    `_assessment()` picks the most recently retrieved assessment, which reads
    `snapshot.retrieved_at`. Without loading the snapshot up front, that read is
    lazy IO in a sync context and SQLAlchemy raises MissingGreenlet — so this
    chain is load-bearing, not an optimisation.
    """
    return selectinload(SeafoodItem.wwf_assessments).selectinload(
        WwfAssessment.snapshot
    )


# The schema stores taxonomic family, which is precise but means nothing to a
# shopper standing at a stall. These labels answer the question they actually
# have — where does this fish live, and is it farmed? — without adding a column
# that would need curating for every future species.
FAMILY_LABELS: dict[str, str] = {
    "Scombridae": "Pelagic fish",
    "Carangidae": "Demersal fish",
    "Lutjanidae": "Reef / demersal fish",
    "Serranidae": "Grouper / reef fish",
    "Cichlidae": "Farmed freshwater fish",
    "Clupeidae": "Pelagic fish",
    "Sciaenidae": "Demersal fish",
    "Latidae": "Coastal / farmed fish",
    "Penaeidae": "Prawn",
    "Portunidae": "Crab",
}


def _fish_type(item: SeafoodItem) -> str:
    """Shopper-facing type label, falling back to the taxonomic family."""
    if not item.family:
        return "Seafood"
    return FAMILY_LABELS.get(item.family, item.family)


# --- reads -------------------------------------------------------------------


async def list_seafood(session: AsyncSession) -> list[SeafoodItem]:
    """All active supported species, with their WWF assessment preloaded."""
    stmt = (
        select(SeafoodItem)
        .where(SeafoodItem.active.is_(True))
        .options(_assessment_loader())
        .order_by(SeafoodItem.code)
    )
    return list(await session.scalars(stmt))


async def get_seafood_by_id(session: AsyncSession, fish_id: str) -> SeafoodItem | None:
    """Resolve the public identifier (`code`) to a canonical record."""
    stmt = (
        select(SeafoodItem)
        .where(func.upper(SeafoodItem.code) == fish_id.strip().upper())
        .options(
            selectinload(SeafoodItem.aliases),
            _assessment_loader(),
            selectinload(SeafoodItem.cooking_suitability).selectinload(
                CookingSuitability.method
            ),
        )
    )
    return await session.scalar(stmt)


async def search_seafood(session: AsyncSession, query: str) -> list[SeafoodItem]:
    """Alias-first search.

    Matching runs on LOWER(TRIM(alias_name)) so it uses idx_seafood_alias_search
    rather than scanning. Exact alias matches sort first: someone typing
    "kembung" wants Kembung at the top, not whatever else contains the string.
    """
    q = query.strip().lower()
    if not q:
        return []

    normalised = func.lower(func.trim(SeafoodAlias.alias_name))
    stmt = (
        select(SeafoodItem, func.min(func.length(SeafoodAlias.alias_name)).label("best"))
        .join(SeafoodAlias, SeafoodAlias.seafood_item_id == SeafoodItem.seafood_item_id)
        .where(SeafoodItem.active.is_(True))
        .where(normalised.like(f"%{q}%"))
        .options(_assessment_loader())
        .group_by(SeafoodItem.seafood_item_id)
        .order_by(
            # exact alias match first, then shortest matching alias
            func.min(func.abs(func.length(SeafoodAlias.alias_name) - len(q))),
            "best",
        )
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
        .options(_assessment_loader())
        .order_by(CookingSuitability.suitability_score.desc(), SeafoodItem.code)
    )
    return list(await session.scalars(stmt))


# --- mapping to the API contract ---------------------------------------------


def _assessment(item: SeafoodItem) -> WwfAssessment | None:
    """The assessment to display, or None for UNDETERMINED.

    A species can accumulate assessments across snapshots; the most recently
    retrieved one wins.
    """
    if not item.wwf_assessments:
        return None
    return max(
        item.wwf_assessments,
        key=lambda a: (a.snapshot.retrieved_at if a.snapshot else None) or "",
    )


def to_summary(item: SeafoodItem) -> SeafoodSummaryOut:
    """Compact card for search results and lists."""
    assessment = _assessment(item)
    return SeafoodSummaryOut(
        fish_id=item.code,
        scientific_name=item.scientific_name,
        primary_common_name=item.canonical_name_ms,
        fish_type=_fish_type(item),
        image_url=firebase.image_url(item.code),
        classification=RATING_LABELS[assessment.rating] if assessment else UNDETERMINED,
    )


def to_sustainability(item: SeafoodItem) -> SustainabilityOut:
    """WWF payload, including the honest 'we don't know' case."""
    assessment = _assessment(item)

    if assessment is None:
        return SustainabilityOut(
            classification=UNDETERMINED,
            origin="Varies — confirm at purchase",
            production_method="Wild-caught or farmed (confirm at purchase)",
            explanation=UNDETERMINED_EXPLANATION,
            why_it_matters=UNDETERMINED_WHY,
            source_name="WWF Save Our Seafood",
            source_url="https://www.saveourseafood.my/",
            verified=False,
        )

    return SustainabilityOut(
        classification=RATING_LABELS[assessment.rating],
        origin=assessment.origin_raw or "Malaysia",
        production_method=assessment.production_method_raw or "",
        explanation=assessment.notes_raw or "",
        why_it_matters=WHY_IT_MATTERS[assessment.rating],
        source_name="WWF Save Our Seafood",
        source_url="https://www.saveourseafood.my/",
        verified=True,
    )


async def build_profile(session: AsyncSession, item: SeafoodItem) -> SeafoodProfileOut:
    """Full decision-journey profile for one species."""
    cooking = sorted(
        item.cooking_suitability,
        key=lambda c: (-(c.suitability_score or 0), c.method.code),
    )

    return SeafoodProfileOut(
        fish_id=item.code,
        scientific_name=item.scientific_name,
        primary_common_name=item.canonical_name_ms,
        fish_type=_fish_type(item),
        common_in="Malaysia",
        market_availability="Year-round",
        about=item.notes or "",
        image_url=firebase.image_url(item.code),
        aliases=[
            AliasOut(alias=a.alias_name, language=a.language_code or "ms")
            for a in sorted(item.aliases, key=lambda a: a.alias_name)
        ],
        sustainability=to_sustainability(item),
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
        supply=await get_supply_context(session),
    )


async def get_supply_context(session: AsyncSession) -> SupplyContextOut | None:
    """National landings context.

    Deliberately NOT species-specific: the published landings data has no
    species dimension, so attaching it to one fish would invent a fact.
    """
    stmt = (
        select(SupplyLandingPoint)
        .where(SupplyLandingPoint.scope_level == "NATIONAL")
        .order_by(SupplyLandingPoint.period_month.desc())
        .limit(13)
    )
    points = list(await session.scalars(stmt))

    if not points:
        return SupplyContextOut(
            summary=(
                "Landings data has not been loaded yet. Supply context is "
                "unavailable rather than estimated."
            ),
            trend_label="Unavailable",
            source_name="OpenDOSM Fish Landings",
        )

    latest = points[0]
    year_ago = points[-1] if len(points) == 13 else None

    trend = "Stable"
    if year_ago and year_ago.landings_mt:
        change = float(latest.landings_mt - year_ago.landings_mt) / float(year_ago.landings_mt)
        if change > 0.05:
            trend = "Rising"
        elif change < -0.05:
            trend = "Declining"

    return SupplyContextOut(
        summary=(
            f"National marine landings for {latest.period_month:%B %Y} were "
            f"{float(latest.landings_mt):,.0f} tonnes. This is whole-fishery "
            "context, not a species-level forecast."
        ),
        trend_label=trend,
        source_name="OpenDOSM Fish Landings",
    )


async def get_price_context(session: AsyncSession, fish_id: str) -> PriceContextOut:
    """Observed price context for one species.

    Walks species -> price_item_mapping -> pricecatcher_item -> price_summary,
    taking the highest-priority mapping. Anything not marked DISPLAYABLE is
    reported as insufficient data; a median from three observations in one shop
    is worse than no number at all.
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

    mapping = await session.scalar(
        select(PriceItemMapping)
        .where(PriceItemMapping.seafood_item_id == item.seafood_item_id)
        .order_by(PriceItemMapping.priority)
        .limit(1)
    )

    if mapping is None:
        return PriceContextOut(
            fish_id=item.code,
            latest_price_rm_per_kg=None,
            status="No PriceCatcher mapping",
            change_vs_recent_pct=None,
            history=[],
            disclaimer=PRICE_DISCLAIMER,
        )

    summary = await session.scalar(
        select(PriceSummary)
        .where(PriceSummary.pricecatcher_item_id == mapping.pricecatcher_item_id)
        .where(PriceSummary.window_days == 30)
        .order_by(PriceSummary.period_end.desc())
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
            .where(PriceTrendPoint.pricecatcher_item_id == mapping.pricecatcher_item_id)
            .where(PriceTrendPoint.location_id == summary.location_id)
            .where(PriceTrendPoint.quality_status == PriceQuality.DISPLAYABLE)
            .order_by(PriceTrendPoint.week_start.desc())
            .limit(12)
        )
    )
    trend.reverse()

    change_pct = None
    if len(trend) >= 2 and trend[0].weekly_median:
        change_pct = round(
            float(trend[-1].weekly_median - trend[0].weekly_median)
            / float(trend[0].weekly_median)
            * 100,
            1,
        )

    return PriceContextOut(
        fish_id=item.code,
        latest_price_rm_per_kg=float(summary.median_price),
        status="Observed",
        change_vs_recent_pct=change_pct,
        history=[
            PricePointOut(
                observed_date=p.week_start,
                price_rm_per_kg=float(p.weekly_median),
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
    "get_supply_context",
    "list_seafood",
    "mock_identify",
    "recommend_for_cooking",
    "search_seafood",
    "to_summary",
    "to_sustainability",
]
