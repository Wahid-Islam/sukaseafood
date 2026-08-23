"""Seafood domain services used by API routes."""

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import get_settings
from app.models import (
    CookingSuitability,
    PriceObservation,
    SeafoodAlias,
    SeafoodItem,
    SupplyContext,
)
from app.schemas import (
    IdentifyCandidate,
    IdentifyResponse,
    PriceContextOut,
    PricePointOut,
    SeafoodProfileOut,
    SeafoodSummaryOut,
    SupplyContextOut,
)


async def search_seafood(session: AsyncSession, query: str) -> list[SeafoodItem]:
    """Resolve a search term to canonical seafood records via aliases."""
    q = query.strip().lower()
    if not q:
        return []

    stmt = (
        select(SeafoodItem)
        .join(SeafoodAlias)
        .options(selectinload(SeafoodItem.sustainability))
        .where(func.lower(SeafoodAlias.alias).like(f"%{q}%"))
        .distinct()
    )
    result = await session.scalars(stmt)
    return list(result)


async def get_seafood_by_id(
    session: AsyncSession,
    fish_id: str,
) -> SeafoodItem | None:
    """Load a full seafood profile with related layers."""
    stmt = (
        select(SeafoodItem)
        .where(SeafoodItem.fish_id == fish_id)
        .options(
            selectinload(SeafoodItem.aliases),
            selectinload(SeafoodItem.sustainability),
            selectinload(SeafoodItem.cooking),
        )
    )
    return await session.scalar(stmt)


async def list_seafood(session: AsyncSession) -> list[SeafoodItem]:
    """Return all supported Iteration 1 species."""
    stmt = (
        select(SeafoodItem)
        .options(selectinload(SeafoodItem.sustainability))
        .order_by(SeafoodItem.primary_common_name)
    )
    result = await session.scalars(stmt)
    return list(result)


def to_summary(item: SeafoodItem) -> SeafoodSummaryOut:
    """Map ORM seafood item to summary schema."""
    classification = None
    if item.sustainability is not None:
        classification = item.sustainability.classification
    return SeafoodSummaryOut(
        fish_id=item.fish_id,
        scientific_name=item.scientific_name,
        primary_common_name=item.primary_common_name,
        fish_type=item.fish_type,
        image_url=item.image_url,
        classification=classification,
    )


async def build_profile(
    session: AsyncSession,
    item: SeafoodItem,
) -> SeafoodProfileOut:
    """Attach supply context onto the seafood profile payload."""
    supply = await session.scalar(
        select(SupplyContext).where(SupplyContext.fish_id == item.fish_id)
    )
    profile = SeafoodProfileOut.model_validate(item)
    if supply is not None:
        profile.supply = SupplyContextOut.model_validate(supply)
    return profile


async def get_price_context(
    session: AsyncSession,
    fish_id: str,
) -> PriceContextOut:
    """Build observed price context or an unavailable status."""
    stmt = (
        select(PriceObservation)
        .where(PriceObservation.fish_id == fish_id)
        .order_by(PriceObservation.observed_date.asc())
    )
    points = list(await session.scalars(stmt))
    if not points:
        return PriceContextOut(
            fish_id=fish_id,
            latest_price_rm_per_kg=None,
            status="Unavailable",
            change_vs_recent_pct=None,
            history=[],
        )

    history = [PricePointOut.model_validate(p) for p in points]
    latest = points[-1].price_rm_per_kg
    change = None
    if len(points) >= 2:
        baseline = points[0].price_rm_per_kg
        if baseline:
            change = round(((latest - baseline) / baseline) * 100, 1)

    return PriceContextOut(
        fish_id=fish_id,
        latest_price_rm_per_kg=latest,
        status="Observed",
        change_vs_recent_pct=change,
        history=history,
    )


async def recommend_for_cooking(
    session: AsyncSession,
    method: str,
) -> list[SeafoodItem]:
    """Rank verified seafood suitability for a cooking method."""
    normalized = method.strip().lower()
    stmt = (
        select(SeafoodItem)
        .join(CookingSuitability)
        .options(selectinload(SeafoodItem.sustainability))
        .where(
            CookingSuitability.method == normalized,
            CookingSuitability.verified.is_(True),
        )
        .order_by(CookingSuitability.suitability_score.desc())
    )
    return list(await session.scalars(stmt))


async def mock_identify(
    session: AsyncSession,
    hint: str | None = None,
) -> IdentifyResponse:
    """
    Return a mock CV top-3 prediction.

    Iteration 1 allows a stable mock until the Fish-Vista-backed model is ready.
    Pass hint=cv_class or common name to bias the mock winner for demos.
    """
    settings = get_settings()
    items = await list_seafood(session)
    if not items:
        raise ValueError("No seafood seed data available for identify.")

    ranked = items
    if hint:
        h = hint.strip().lower()
        ranked = sorted(
            items,
            key=lambda i: (
                0
                if h in i.cv_class.lower()
                or h in i.primary_common_name.lower()
                or h in i.scientific_name.lower()
                else 1
            ),
        )

    confidences = [0.86, 0.09, 0.03]
    candidates: list[IdentifyCandidate] = []
    for item, confidence in zip(ranked[:3], confidences, strict=False):
        candidates.append(
            IdentifyCandidate(
                fish_id=item.fish_id,
                primary_common_name=item.primary_common_name,
                scientific_name=item.scientific_name,
                confidence=confidence,
            )
        )

    return IdentifyResponse(
        model_version=settings.identify_model_version,
        top_prediction=candidates[0],
        alternatives=candidates[1:],
        requires_user_confirmation=True,
        is_mock=True,
    )


async def resolve_alias_or_name(
    session: AsyncSession,
    term: str,
) -> SeafoodItem | None:
    """Exact-ish resolve used by search confirmation flows."""
    q = term.strip().lower()
    stmt = (
        select(SeafoodItem)
        .join(SeafoodAlias, isouter=True)
        .options(selectinload(SeafoodItem.sustainability))
        .where(
            or_(
                func.lower(SeafoodItem.primary_common_name) == q,
                func.lower(SeafoodItem.scientific_name) == q,
                func.lower(SeafoodItem.fish_id) == q,
                func.lower(SeafoodAlias.alias) == q,
            )
        )
        .limit(1)
    )
    return await session.scalar(stmt)
