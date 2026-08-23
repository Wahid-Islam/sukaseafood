"""Pydantic request/response schemas."""

from datetime import date

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
    """One CV prediction candidate."""

    fish_id: str
    primary_common_name: str
    scientific_name: str
    confidence: float = Field(ge=0.0, le=1.0)


class IdentifyResponse(BaseModel):
    """Mock / real CV identify response."""

    model_version: str
    top_prediction: IdentifyCandidate
    alternatives: list[IdentifyCandidate]
    requires_user_confirmation: bool = True
    is_mock: bool = True


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
