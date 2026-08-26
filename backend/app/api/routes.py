"""API route modules."""

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app import firebase
from app.config import get_settings
from app.database import get_db, ping, schema_is_present
from app.schemas import (
    CookingRecommendationOut,
    DatabaseHealthOut,
    HealthOut,
    IdentifyResponse,
    PriceContextOut,
    SearchResponse,
    SeafoodProfileOut,
    SeafoodSummaryOut,
    SourceMetaOut,
)
from app.models import SeafoodItem
from app.services import seafood as seafood_service

router = APIRouter()


@router.get("/health", response_model=HealthOut)
async def health() -> HealthOut:
    """Liveness probe."""
    settings = get_settings()
    return HealthOut(
        status="ok",
        app=settings.app_name,
        version=settings.app_version,
    )


@router.get("/health/db", response_model=DatabaseHealthOut)
async def database_health(db: AsyncSession = Depends(get_db)) -> DatabaseHealthOut:
    """Readiness probe: can we reach Postgres, and is the schema applied?

    Returns 200 with a degraded status rather than raising, so a monitoring
    system can distinguish "unreachable" from "reachable but unmigrated" —
    two very different pages at 3am.
    """
    reachable = await ping()
    if not reachable:
        return DatabaseHealthOut(
            status="unavailable",
            database="unreachable",
            schema_applied=False,
            firebase=firebase.status(),
        )

    applied = await schema_is_present()
    count = None
    if applied:
        count = await db.scalar(select(func.count()).select_from(SeafoodItem))

    return DatabaseHealthOut(
        status="ok" if applied and count else "degraded",
        database="postgresql",
        schema_applied=applied,
        seafood_count=count,
        firebase=firebase.status(),
    )


@router.get("/seafood", response_model=list[SeafoodSummaryOut])
async def list_supported_seafood(
    db: AsyncSession = Depends(get_db),
) -> list[SeafoodSummaryOut]:
    """List the five Iteration 1 supported species."""
    items = await seafood_service.list_seafood(db)
    return [seafood_service.to_summary(i) for i in items]


@router.get("/search", response_model=SearchResponse)
async def search(
    q: str = Query(..., min_length=1, description="Seafood name or alias"),
    db: AsyncSession = Depends(get_db),
) -> SearchResponse:
    """Search by local name, English name, or scientific name."""
    items = await seafood_service.search_seafood(db, q)
    return SearchResponse(
        query=q,
        results=[seafood_service.to_summary(i) for i in items],
    )


@router.get("/seafood/{fish_id}", response_model=SeafoodProfileOut)
async def seafood_profile(
    fish_id: str,
    db: AsyncSession = Depends(get_db),
) -> SeafoodProfileOut:
    """Return the full decision-support profile for one fish_id."""
    item = await seafood_service.get_seafood_by_id(db, fish_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Seafood not found")
    return await seafood_service.build_profile(db, item)


@router.get("/seafood/{fish_id}/price", response_model=PriceContextOut)
async def seafood_price(
    fish_id: str,
    db: AsyncSession = Depends(get_db),
) -> PriceContextOut:
    """Observed price context (PriceCatcher-backed seed for I1)."""
    item = await seafood_service.get_seafood_by_id(db, fish_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Seafood not found")
    return await seafood_service.get_price_context(db, fish_id)


@router.get("/cooking/{method}", response_model=CookingRecommendationOut)
async def cooking_recommendations(
    method: str,
    db: AsyncSession = Depends(get_db),
) -> CookingRecommendationOut:
    """Recommend seafood for a cooking method (Epic 4)."""
    items = await seafood_service.recommend_for_cooking(db, method)
    return CookingRecommendationOut(
        method=method.lower(),
        recommendations=[seafood_service.to_summary(i) for i in items],
    )


@router.post("/identify", response_model=IdentifyResponse)
async def identify_seafood(
    hint: str | None = Query(
        default=None,
        description="Optional demo hint to bias mock CV result",
    ),
    image: UploadFile | None = File(default=None),
    db: AsyncSession = Depends(get_db),
) -> IdentifyResponse:
    """
    Computer-vision identify endpoint.

    Iteration 1 ships a mock adapter. Accepts an optional image upload so the
    mobile camera flow can integrate early. Fish-Vista model swaps in later.
    """
    _ = image  # Reserved for real CV adapter.
    try:
        return await seafood_service.mock_identify(db, hint=hint)
    except ValueError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.get("/sources", response_model=list[SourceMetaOut])
async def sources() -> list[SourceMetaOut]:
    """Traceable data sources shown in-app."""
    return [
        SourceMetaOut(
            name="WWF Save Our Seafood",
            role="Sustainability classification",
            url="https://www.saveourseafood.my/",
            license_note="Cite WWF SOS; verify listing before demo claims.",
        ),
        SourceMetaOut(
            name="OpenDOSM PriceCatcher",
            role="Observed price context",
            url="https://open.dosm.gov.my/",
            license_note="Observed local prices, not national CPI average.",
        ),
        SourceMetaOut(
            name="OpenDOSM Fish Landings",
            role="Broader supply context",
            url="https://open.dosm.gov.my/",
            license_note="Not species-level forecasting.",
        ),
        SourceMetaOut(
            name="Fish-Vista (Imageomics)",
            role="Future CV / trait identification backbone",
            url="https://github.com/sajeedmehrab/Fish-Vista",
            license_note="Cite Fish-Vista + original museum sources.",
        ),
        SourceMetaOut(
            name="OBIS",
            role="Future marine biodiversity context",
            url="https://portal.obis.org/data/access/",
            license_note="Mostly CC BY 4.0; verify per-dataset licence.",
        ),
    ]
