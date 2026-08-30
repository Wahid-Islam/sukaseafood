"""Pydantic request/response schemas."""

import uuid
from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class AliasOut(BaseModel):
    """Seafood alias."""

    alias: str
    language: str

    model_config = ConfigDict(from_attributes=True)


class SustainabilityOut(BaseModel):
    """WWF sustainability payload."""

    classification: str
    origin: str
    production_method: str
    explanation: str
    why_it_matters: str
    source_name: str
    source_url: str
    verified: bool

    model_config = ConfigDict(from_attributes=True)


class PricePointOut(BaseModel):
    """Single observed price point."""

    observed_date: date
    price_rm_per_kg: float
    premise_state: str
    premise_type: str
    note: str

    model_config = ConfigDict(from_attributes=True)


class PriceContextOut(BaseModel):
    """Price intelligence summary for a seafood item."""

    fish_id: str
    latest_price_rm_per_kg: float | None
    status: str
    change_vs_recent_pct: float | None
    history: list[PricePointOut]
    disclaimer: str = (
        "Observed price context from OpenDOSM PriceCatcher — "
        "not a nationally representative average."
    )


class SupplyContextOut(BaseModel):
    """Supply / landings context."""

    summary: str
    trend_label: str
    source_name: str

    model_config = ConfigDict(from_attributes=True)


class CookingSuitabilityOut(BaseModel):
    """Cooking suitability row."""

    method: str
    suitability_score: float
    rationale: str
    verified: bool

    model_config = ConfigDict(from_attributes=True)


class SeafoodSummaryOut(BaseModel):
    """Compact seafood card for search / lists."""

    fish_id: str
    scientific_name: str
    primary_common_name: str
    fish_type: str
    image_url: str | None
    classification: str | None = None

    model_config = ConfigDict(from_attributes=True)


class SeafoodProfileOut(BaseModel):
    """Full seafood profile used by the decision journey."""

    fish_id: str
    scientific_name: str
    primary_common_name: str
    fish_type: str
    common_in: str
    market_availability: str
    about: str
    image_url: str | None
    aliases: list[AliasOut]
    sustainability: SustainabilityOut | None
    cooking: list[CookingSuitabilityOut]
    supply: SupplyContextOut | None = None

    model_config = ConfigDict(from_attributes=True)


class SearchResponse(BaseModel):
    """Search results."""

    query: str
    results: list[SeafoodSummaryOut]


class IdentifyCandidate(BaseModel):
    """One ranked candidate, already resolved to a canonical seafood_item."""

    rank: int = Field(ge=1)
    # The canonical key. Every downstream call — sustainability, price,
    # cooking, favourites — takes this id, not a name or a model class code.
    seafood_item_id: uuid.UUID
    code: str
    canonical_name_ms: str
    display_name_en: str
    scientific_name: str
    confidence: float = Field(ge=0.0, le=1.0)


class IdentifyResponse(BaseModel):
    """POST /identify response.

    status is a BUSINESS state carried on HTTP 200:
      CANDIDATES      top-1 cleared the model's validated threshold
      LOW_CONFIDENCE  it did not, or no threshold has been validated yet

    Both return candidates. Neither settles an identity: the user confirms one
    or picks "None of these", and only then is the fish treated as identified.
    """

    status: Literal["CANDIDATES", "LOW_CONFIDENCE"]
    model_version: str
    confirmation_required: bool = True
    image_persisted: bool = False
    candidates: list[IdentifyCandidate]


class CookingRecommendationOut(BaseModel):
    """Recommended seafood for a cooking method."""

    method: str
    recommendations: list[SeafoodSummaryOut]


class SourceMetaOut(BaseModel):
    """Traceable data source metadata."""

    name: str
    role: str
    url: str
    license_note: str


class HealthOut(BaseModel):
    """Health check payload."""

    status: str
    app: str
    version: str

class DatabaseHealthOut(BaseModel):
    """Dependency health — what /health/db reports.

    Split from the plain liveness probe on purpose: a container that is up but
    cannot reach Postgres should fail a readiness check while still answering
    /health, so orchestrators stop routing traffic to it without killing it.
    """

    status: str
    database: str
    schema_applied: bool
    seafood_count: int | None = None
    firebase: dict = {}
