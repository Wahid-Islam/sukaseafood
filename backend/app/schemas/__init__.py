"""Pydantic request/response schemas."""

import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class AliasOut(BaseModel):
    """Seafood alias."""

    alias: str
    language: str

    model_config = ConfigDict(from_attributes=True)


class MethodRatingOut(BaseModel):
    """One WWF rating for one catch or production method."""

    classification: str
    production_method: str
    production_method_code: str
    origin: str
    explanation: str

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
    assessments: list[MethodRatingOut] = Field(default_factory=list)

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


class ForecastLocationOut(BaseModel):
    """The location a forecast applies to. Production scope is Selangor."""

    location_id: uuid.UUID
    state_name: str

    model_config = ConfigDict(from_attributes=True)


class ForecastReferenceOut(BaseModel):
    """The observed price the forecast was made from.

    Carried alongside the forecast so the UI can show "expected RM15.90,
    currently RM15.90" without a second request, and so the comparison is
    always against the week the model actually used rather than whatever the
    latest observation happens to be.
    """

    week_start: date | None
    price: float | None


class ForecastWeekOut(BaseModel):
    """One forecast week.

    Three prices, not one. `expected_price` is the model point estimate and
    the bounds are the prediction interval; presenting the point estimate alone
    would imply a precision the model does not have.
    """

    forecast_week_start: date
    horizon_weeks: int | None
    expected_price: float
    lower_bound: float
    upper_bound: float

    # Directional verdict. NO_STRONG_SIGNAL is a real answer meaning the
    # evidence did not justify claiming a move — it must not be relabelled
    # STABLE, which would assert something the model never concluded.
    outlook: str | None
    outlook_label: str | None
    directional_outlook_label: str | None

    # VALID or SPARSE_DATA. A SPARSE_DATA forecast is displayable but rests on
    # thin recent PriceCatcher coverage, and the UI must say so rather than
    # presenting it with the same confidence as a dense series.
    quality_status: str | None
    model_used: str | None


class ForecastModelOut(BaseModel):
    """Which model version produced the forecast, for traceability."""

    model_version_id: uuid.UUID
    version_name: str
    algorithm: str
    interval_level: float | None

    # The contract names these fields model_*; clearing the protected namespace
    # keeps that naming without Pydantic shadowing warnings.
    model_config = ConfigDict(from_attributes=True, protected_namespaces=())


class PriceForecastOut(BaseModel):
    """GET /seafood/{fish_id}/forecast — the Step 33C contract.

    Everything here is computed upstream by the R pipeline and stored. The
    client renders it; it does not model, re-range, re-date or re-interpret
    anything.
    """

    fish_id: str
    seafood_item_id: uuid.UUID
    canonical_name: str
    display_name: str
    location: ForecastLocationOut
    reference: ForecastReferenceOut
    forecast: list[ForecastWeekOut]
    model: ForecastModelOut
    generated_at: datetime | None
    source_name: str = "SukaSeafood Price Forecast Engine"
    disclaimer: str = (
        "Modelled outlook derived from OpenDOSM PriceCatcher observations. "
        "An estimated range, not an official or guaranteed price."
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


class OccurrenceOut(BaseModel):
    """One OBIS observation used on the distribution map."""

    latitude: float
    longitude: float
    country: str | None = None
    locality: str | None = None
    event_date: str | None = None

    model_config = ConfigDict(from_attributes=True)


class BiodiversitySourceOut(BaseModel):
    """Whether a cited biodiversity publisher has usable rows on file."""

    key: str
    name: str
    available: bool
    url: str = ""
    unavailable_reason: str | None = None

    model_config = ConfigDict(from_attributes=True)


class BiodiversityOut(BaseModel):
    """Retrieved FishBase / OBIS / IUCN facts, plus catalogue taxonomy.

    Missing fields stay unavailable. MyBIS national status and Reef Check
    survey metrics are never invented.
    """

    family: str | None = None
    habitat_group: str | None = None
    taxonomic_level: str | None = None
    ecosystem_note: str | None = None
    depth_shallow_m: float | None = None
    depth_deep_m: float | None = None
    ecological_role: str | None = None
    iucn_category: str | None = None
    iucn_label: str | None = None
    iucn_url: str | None = None
    fishbase_url: str | None = None
    population_trend: str | None = None
    mybis_national_status: str | None = None
    occurrences: list[OccurrenceOut] = Field(default_factory=list)
    sources: list[BiodiversitySourceOut] = Field(default_factory=list)
    available: bool
    source_name: str
    source_url: str
    unavailable_reason: str | None = None

    model_config = ConfigDict(from_attributes=True)


class SeafoodSummaryOut(BaseModel):
    """Compact seafood card for search / lists."""

    fish_id: str
    scientific_name: str
    primary_common_name: str
    display_name_en: str
    fish_type: str
    image_url: str | None
    classification: str | None = None
    description: str = ""
    suitable_methods: list[str] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class SeafoodProfileOut(BaseModel):
    """Full seafood profile used by the decision journey."""

    fish_id: str
    scientific_name: str
    primary_common_name: str
    display_name_en: str = ""
    fish_type: str
    family: str | None = None
    common_in: str
    market_availability: str
    about: str
    image_url: str | None
    aliases: list[AliasOut]
    sustainability: SustainabilityOut | None
    biodiversity: BiodiversityOut | None = None
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
    git_sha: str | None = None

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
