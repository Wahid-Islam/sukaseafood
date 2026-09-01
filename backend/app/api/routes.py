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
    PriceForecastOut,
    SearchResponse,
    SeafoodProfileOut,
    SeafoodSummaryOut,
    SourceMetaOut,
)
from app.models import SeafoodItem
from app.services import cv as cv_service
from app.services import forecast as forecast_service
from app.services import read_cache
from app.services import seafood as seafood_service

router = APIRouter()


def _error(code: str, message: str) -> dict:
    """The standard error envelope."""
    return {"error": {"code": code, "message": message, "details": {}}}


@router.get("/health", response_model=HealthOut)
async def health() -> HealthOut:
    """Liveness probe."""
    settings = get_settings()
    return HealthOut(
        status="ok",
        app=settings.app_name,
        version=settings.app_version,
        git_sha=settings.git_sha or None,
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
    """List every active canonical species."""
    cached = read_cache.get("seafood:list", ttl_seconds=60)
    if isinstance(cached, list):
        return cached
    items = await seafood_service.list_seafood(db)
    summaries = [seafood_service.to_summary(i) for i in items]
    read_cache.put("seafood:list", summaries)
    return summaries


@router.get("/search", response_model=SearchResponse)
async def search(
    q: str = Query(..., min_length=1, description="Seafood name or alias"),
    db: AsyncSession = Depends(get_db),
) -> SearchResponse:
    """Search by local name, English name, or scientific name."""
    cache_key = f"seafood:search:{q.strip().lower()}"
    cached = read_cache.get(cache_key, ttl_seconds=60)
    if isinstance(cached, SearchResponse):
        return cached
    items = await seafood_service.search_seafood(db, q)
    payload = SearchResponse(
        query=q,
        results=[seafood_service.to_summary(i) for i in items],
    )
    read_cache.put(cache_key, payload)
    return payload


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


@router.get("/seafood/{fish_id}/forecast", response_model=PriceForecastOut)
async def seafood_price_forecast(
    fish_id: str,
    location_id: str | None = Query(
        None, description="Defaults to Selangor, the engine's production scope."
    ),
    weeks: int = Query(
        forecast_service.DEFAULT_WEEKS,
        ge=1,
        le=forecast_service.DEFAULT_WEEKS,
        description="Forecast weeks to return, nearest first.",
    ),
    db: AsyncSession = Depends(get_db),
) -> PriceForecastOut:
    """Modelled four-week price outlook for one canonical species (Step 33C).

    Every value is generated upstream by the R forecasting pipeline and stored.
    The client presents it and must not recompute ranges, direction, dates or
    confidence — the whole point of serving it from the database is that what a
    shopper sees is what the validated engine actually produced.

    A fish with no forecast is normal rather than exceptional: the engine only
    covers species that pass its data-eligibility rules, so 404
    FORECAST_UNAVAILABLE is a state the UI is expected to render.
    """
    item = await seafood_service.get_seafood_by_id(db, fish_id)
    if item is None:
        raise HTTPException(
            status_code=404,
            detail=_error("SEAFOOD_NOT_FOUND", "Seafood item was not found."),
        )

    try:
        cache_key = f"forecast:{item.code}:{location_id or 'default'}:{weeks}"
        cached = read_cache.get(cache_key, ttl_seconds=120)
        if isinstance(cached, PriceForecastOut):
            return cached
        payload = await forecast_service.get_forecast(
            db, item, location_id=location_id, weeks=weeks
        )
        read_cache.put(cache_key, payload)
        return payload
    except forecast_service.InvalidLocation as exc:
        raise HTTPException(
            status_code=400,
            detail=_error("INVALID_LOCATION", str(exc)),
        ) from exc
    except forecast_service.ForecastUnavailable as exc:
        raise HTTPException(
            status_code=404,
            detail=_error("FORECAST_UNAVAILABLE", str(exc)),
        ) from exc


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


ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_UPLOAD_BYTES = 10 * 1024 * 1024


@router.post("/identify", response_model=IdentifyResponse)
async def identify_seafood(
    file: UploadFile = File(..., description="One whole fish. JPEG/PNG/WebP, <=10 MB."),
    db: AsyncSession = Depends(get_db),
) -> IdentifyResponse:
    """Identify a fish from one photograph.

    Returns up to three ranked candidates, each already resolved to a canonical
    seafood_item_id. The result is a SUGGESTION: the client shows all of them
    and the user confirms one, or chooses "None of these". Sustainability,
    price and cooking are only applicable to a confirmed species.

    The uploaded image is never stored. It exists as one local variable for the
    life of the request and is dropped when it returns.
    """
    # 415 and 413 are decided before the model is touched, so a junk upload
    # cannot spend inference CPU.
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail=_error("UNSUPPORTED_MEDIA_TYPE",
                          "Image must be JPEG, PNG or WebP."),
        )

    image_bytes = await file.read()

    if len(image_bytes) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=_error("IMAGE_TOO_LARGE", "Image exceeds the 10 MB limit."),
        )

    try:
        result = cv_service.get_adapter().predict(image_bytes)
    except cv_service.CvUnavailable as exc:
        raise HTTPException(503, detail=_error("MODEL_UNAVAILABLE", str(exc))) from exc
    except Exception as exc:  # the adapter's own typed errors
        name = type(exc).__name__
        if name == "ImageTooLargeError":
            raise HTTPException(413, detail=_error("IMAGE_TOO_LARGE", str(exc))) from exc
        if name == "InvalidImageError":
            raise HTTPException(422, detail=_error("INVALID_IMAGE_CONTENT", str(exc))) from exc
        if name == "ModelUnavailableError":
            raise HTTPException(503, detail=_error("MODEL_UNAVAILABLE", str(exc))) from exc
        raise
    finally:
        # No durable storage of user photographs, and none are reused as
        # training data.
        del image_bytes

    # A class the active model has no mapping for is a configuration error, not
    # something to guess past. It belongs in the same 503 bucket as a missing
    # model: the scanner genuinely cannot serve an answer, and naming the wrong
    # fish would be worse than saying so.
    try:
        candidates = await cv_service.resolve_candidates(
            db, result["model_version"], result["predictions"]
        )
    except cv_service.CvUnavailable as exc:
        raise HTTPException(503, detail=_error("MODEL_UNAVAILABLE", str(exc))) from exc

    return IdentifyResponse(
        status=result["status"],       # CANDIDATES or LOW_CONFIDENCE, both HTTP 200
        model_version=result["model_version"],
        confirmation_required=True,    # always; top-1 is never auto-finalised
        image_persisted=False,
        candidates=candidates,
    )


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
            name="SukaSeafood Price Forecast Engine",
            role="Four-week modelled price outlook",
            url="https://open.dosm.gov.my/",
            license_note=(
                "Our own model over PriceCatcher observations. An estimated "
                "range, not an official or guaranteed price."
            ),
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
