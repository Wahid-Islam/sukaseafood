"""SQLAlchemy ORM models for the SukaSeafood V3 domain (21 tables).

These models MIRROR `backend/db/schema/v3_initial_schema.sql` and the indexes
in `backend/db/schema/v3_functions_indexes.sql`; they do not define them. The
SQL files are the source of truth (they are what gets applied to Cloud SQL and
what the handoff document specifies), and Alembic executes those files
verbatim. Keeping the ORM as a mirror means:

  * `Base.metadata.create_all()` is never used outside tests
  * enum types are referenced, never created, by Python
  * a drift test can compare this metadata against a live database

Shape of the domain — everything hangs off one hub:

    seafood_item
      ├── seafood_alias           (search resolves here)
      ├── wwf_assessment          (absent row == UNDETERMINED)
      ├── cooking_suitability ──> cooking_method
      ├── price_item_mapping  ──> pricecatcher_item
      ├── price_period_summary    (derived rollups keyed by seafood_item_id)
      ├── price_trend_point       (weekly medians keyed by seafood_item_id)
      ├── price_forecast          (model outlook, separate from observed prices)
      ├── cv_class_mapping    ──> cv_model_version
      └── recipe_seafood_mapping ─> recipe

and every fact-bearing table points at a `source_snapshot`, so any number the
app displays can be traced back to a dated extract.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    SmallInteger,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.enums import (
    AggregationRule,
    CollectionMethod,
    LocationLevel,
    MappingConfidence,
    PeriodType,
    PriceMappingType,
    PriceQuality,
    ProductForm,
    RecipeMappingType,
    SeafoodAliasType,
    SustainabilityRating,
)


def _pg_enum(python_enum: type, type_name: str) -> SAEnum:
    """Bind to an existing Postgres enum type.

    `create_type=False` is the important part: the SQL schema owns these types.
    `values_callable` stores the member VALUE ('BEST_CHOICE'), not the Python
    member name, which are identical here but diverge the moment someone
    renames a member.
    """
    return SAEnum(
        python_enum,
        name=type_name,
        native_enum=True,
        create_type=False,
        validate_strings=True,
        values_callable=lambda e: [m.value for m in e],
    )


def _uuid_pk() -> Mapped[uuid.UUID]:
    return mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)


# =============================================================================
# 1. location
# =============================================================================


class Location(Base):
    """A Malaysian state or district.

    Self-referencing: a DISTRICT points at its STATE via `parent_location_id`,
    which is what lets a price rollup fall back from district to state when a
    district has too few observations to be displayable.
    """

    __tablename__ = "location"

    location_id: Mapped[uuid.UUID] = _uuid_pk()
    parent_location_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("location.location_id"), nullable=True
    )
    level: Mapped[LocationLevel] = mapped_column(
        _pg_enum(LocationLevel, "location_level_enum"), nullable=False
    )
    state_name: Mapped[str] = mapped_column(Text, nullable=False)
    district_name: Mapped[str | None] = mapped_column(Text, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    parent: Mapped[Location | None] = relationship(
        remote_side=[location_id], back_populates="children"
    )
    children: Mapped[list[Location]] = relationship(back_populates="parent")

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"<Location {self.state_name}/{self.district_name or '-'}>"


# =============================================================================
# 2. seafood_item  — the hub of the domain
# =============================================================================


class SeafoodItem(Base):
    """A canonical species. Search, CV identify, sustainability, price and
    cooking all resolve to one of these rows.

    `code` (SF001…) is the stable public identifier exposed by the API as
    `fish_id`; `seafood_item_id` stays internal so the surrogate key can change
    without breaking clients.
    """

    __tablename__ = "seafood_item"

    seafood_item_id: Mapped[uuid.UUID] = _uuid_pk()
    code: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    canonical_name_ms: Mapped[str] = mapped_column(Text, nullable=False)
    display_name_en: Mapped[str] = mapped_column(Text, nullable=False)
    scientific_name: Mapped[str] = mapped_column(Text, nullable=False)
    scientific_name_normalized: Mapped[str | None] = mapped_column(Text, nullable=True)
    taxonomic_level: Mapped[str] = mapped_column(Text, nullable=False)
    family: Mapped[str | None] = mapped_column(Text, nullable=True)
    fish_type: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    supports_cv: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    primary_image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )

    aliases: Mapped[list[SeafoodAlias]] = relationship(
        back_populates="seafood", cascade="all, delete-orphan"
    )
    wwf_assessments: Mapped[list[WwfAssessment]] = relationship(back_populates="seafood")
    cooking_suitability: Mapped[list[CookingSuitability]] = relationship(
        back_populates="seafood"
    )
    price_mappings: Mapped[list[PriceItemMapping]] = relationship(back_populates="seafood")
    recipe_mappings: Mapped[list[RecipeSeafoodMapping]] = relationship(
        back_populates="seafood"
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<SeafoodItem {self.code} {self.display_name_en}>"


# =============================================================================
# 3. seafood_alias
# =============================================================================


class SeafoodAlias(Base):
    """Every spelling a shopper might type or a market might print.

    Uniqueness and search both run on LOWER(TRIM(alias_name)) — declared here as
    expression indexes so the ORM metadata matches the SQL schema exactly.
    """

    __tablename__ = "seafood_alias"
    # Both indexes are on the NORMALISED expression, matching the SQL schema.
    # Declared with text() rather than func.lower(column) so the DDL SQLAlchemy
    # would emit is byte-identical to what v3_initial_schema.sql creates.
    __table_args__ = (
        Index("idx_seafood_alias_search", text("lower(trim(alias_name))")),
        Index(
            "uq_seafood_alias_per_seafood",
            "seafood_item_id",
            text("lower(trim(alias_name))"),
            unique=True,
        ),
        Index("idx_seafood_alias_item", "seafood_item_id"),
    )

    seafood_alias_id: Mapped[uuid.UUID] = _uuid_pk()
    seafood_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("seafood_item.seafood_item_id"), nullable=False
    )
    alias_name: Mapped[str] = mapped_column(Text, nullable=False)
    language_code: Mapped[str | None] = mapped_column(Text, nullable=True)
    alias_type: Mapped[SeafoodAliasType] = mapped_column(
        _pg_enum(SeafoodAliasType, "seafood_alias_type_enum"), nullable=False
    )
    verified: Mapped[bool] = mapped_column(Boolean, nullable=False)

    seafood: Mapped[SeafoodItem] = relationship(back_populates="aliases")


# =============================================================================
# 4. data_source  /  5. source_snapshot
# =============================================================================


class DataSource(Base):
    """A publisher: WWF, OpenDOSM, the team's own curation, a CV model."""

    __tablename__ = "data_source"

    data_source_id: Mapped[uuid.UUID] = _uuid_pk()
    source_key: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    owner: Mapped[str | None] = mapped_column(Text, nullable=True)
    type: Mapped[str] = mapped_column(Text, nullable=False)
    homepage_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    license: Mapped[str | None] = mapped_column(Text, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    snapshots: Mapped[list[SourceSnapshot]] = relationship(back_populates="data_source")


class SourceSnapshot(Base):
    """One dated extract from a publisher.

    Fact tables reference a snapshot rather than a source, so importing a newer
    extract adds rows instead of mutating the evidence behind a number a user
    has already been shown.
    """

    __tablename__ = "source_snapshot"

    source_snapshot_id: Mapped[uuid.UUID] = _uuid_pk()
    data_source_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("data_source.data_source_id"), nullable=False
    )
    version_label: Mapped[str] = mapped_column(Text, nullable=False)
    source_period_start: Mapped[date | None] = mapped_column(Date, nullable=True)
    source_period_end: Mapped[date | None] = mapped_column(Date, nullable=True)
    retrieved_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    collection_method: Mapped[CollectionMethod] = mapped_column(
        _pg_enum(CollectionMethod, "collection_method_enum"), nullable=False
    )
    manifest: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    data_source: Mapped[DataSource] = relationship(back_populates="snapshots")


# =============================================================================
# 6. wwf_assessment
# =============================================================================


class WwfAssessment(Base):
    """A WWF Save Our Seafood rating for one species.

    The `*_raw` columns keep WWF's own wording verbatim next to our mapped
    values, so a reviewer can always audit the interpretation. No row for a
    species means UNDETERMINED — never assume a default rating.
    """

    __tablename__ = "wwf_assessment"
    __table_args__ = (
        UniqueConstraint("source_snapshot_id", "source_record_key"),
        Index("idx_wwf_assessment_item", "seafood_item_id"),
    )

    wwf_assessment_id: Mapped[uuid.UUID] = _uuid_pk()
    seafood_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("seafood_item.seafood_item_id"), nullable=False
    )
    source_snapshot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("source_snapshot.source_snapshot_id"), nullable=False
    )
    source_record_key: Mapped[str] = mapped_column(Text, nullable=False)
    common_name_raw: Mapped[str] = mapped_column(Text, nullable=False)
    secondary_common_name_raw: Mapped[str | None] = mapped_column(Text, nullable=True)
    scientific_name_raw: Mapped[str] = mapped_column(Text, nullable=False)
    rating: Mapped[SustainabilityRating] = mapped_column(
        _pg_enum(SustainabilityRating, "sustainability_rating_enum"), nullable=False
    )
    origin_raw: Mapped[str | None] = mapped_column(Text, nullable=True)
    origin_code: Mapped[str | None] = mapped_column(Text, nullable=True)
    production_type: Mapped[str | None] = mapped_column(Text, nullable=True)
    production_method_raw: Mapped[str | None] = mapped_column(Text, nullable=True)
    production_method_code: Mapped[str | None] = mapped_column(Text, nullable=True)
    certification_raw: Mapped[str | None] = mapped_column(Text, nullable=True)
    context: Mapped[str | None] = mapped_column(Text, nullable=True)
    notes_raw: Mapped[str | None] = mapped_column(Text, nullable=True)

    seafood: Mapped[SeafoodItem] = relationship(back_populates="wwf_assessments")
    snapshot: Mapped[SourceSnapshot] = relationship()


# =============================================================================
# 7. pricecatcher_item  /  8. pricecatcher_premise  /  9. price_item_mapping
# =============================================================================


class PriceCatcherItem(Base):
    """An item as OpenDOSM PriceCatcher defines it — not as we define it.

    `product_form` and `unit_code` exist because PriceCatcher lists whole fish,
    fillets and cooked product under similar names. Averaging across forms would
    produce a meaningless price, so form is carried explicitly.
    """

    __tablename__ = "pricecatcher_item"

    pricecatcher_item_id: Mapped[uuid.UUID] = _uuid_pk()
    source_snapshot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("source_snapshot.source_snapshot_id"), nullable=False
    )
    external_item_code: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    official_item_name: Mapped[str] = mapped_column(Text, nullable=False)
    unit_raw: Mapped[str] = mapped_column(Text, nullable=False)
    unit_code: Mapped[str] = mapped_column(Text, nullable=False)
    item_group: Mapped[str | None] = mapped_column(Text, nullable=True)
    item_category: Mapped[str | None] = mapped_column(Text, nullable=True)
    product_form: Mapped[ProductForm] = mapped_column(
        _pg_enum(ProductForm, "product_form_enum"), nullable=False
    )
    size_descriptor: Mapped[str | None] = mapped_column(Text, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    mappings: Mapped[list[PriceItemMapping]] = relationship(back_populates="pricecatcher_item")


class PriceCatcherPremise(Base):
    """A retail outlet as PriceCatcher defines it, tied to a canonical location."""

    __tablename__ = "pricecatcher_premise"

    pricecatcher_premise_id: Mapped[uuid.UUID] = _uuid_pk()
    source_snapshot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("source_snapshot.source_snapshot_id"), nullable=False
    )
    location_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("location.location_id"), nullable=False
    )
    external_premise_code: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    premise_name: Mapped[str] = mapped_column(Text, nullable=False)
    retail_class: Mapped[str] = mapped_column(Text, nullable=False)
    address_raw: Mapped[str | None] = mapped_column(Text, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    location: Mapped[Location] = relationship()


class PriceItemMapping(Base):
    """Bridge from a canonical species to the PriceCatcher items that represent it.

    Many-to-many with an ordering: `priority` picks the best item when several
    match, `is_default_for_generic` handles "ikan merah" with no variant chosen,
    and `requires_variant_confirmation` tells the UI to ask the user which
    variant they are looking at before quoting a price.
    """

    __tablename__ = "price_item_mapping"
    __table_args__ = (
        UniqueConstraint("seafood_item_id", "pricecatcher_item_id"),
        CheckConstraint("priority > 0", name="price_item_mapping_priority_check"),
        Index("idx_price_item_mapping_item", "seafood_item_id", "priority"),
        Index("idx_price_item_mapping_pc_item", "pricecatcher_item_id"),
    )

    price_item_mapping_id: Mapped[uuid.UUID] = _uuid_pk()
    seafood_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("seafood_item.seafood_item_id"), nullable=False
    )
    pricecatcher_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("pricecatcher_item.pricecatcher_item_id"),
        nullable=False,
    )
    mapping_type: Mapped[PriceMappingType] = mapped_column(
        _pg_enum(PriceMappingType, "price_mapping_type_enum"), nullable=False
    )
    priority: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    is_default_for_generic: Mapped[bool] = mapped_column(Boolean, nullable=False)
    requires_variant_confirmation: Mapped[bool] = mapped_column(Boolean, nullable=False)
    aggregation_rule: Mapped[AggregationRule] = mapped_column(
        _pg_enum(AggregationRule, "aggregation_rule_enum"),
        nullable=False,
        default=AggregationRule.SEPARATE,
    )
    mapping_confidence: Mapped[MappingConfidence] = mapped_column(
        _pg_enum(MappingConfidence, "mapping_confidence_enum"),
        nullable=False,
        default=MappingConfidence.MEDIUM,
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    seafood: Mapped[SeafoodItem] = relationship(back_populates="price_mappings")
    pricecatcher_item: Mapped[PriceCatcherItem] = relationship(back_populates="mappings")


# =============================================================================
# 10. price_period_summary  /  11. price_trend_point
# =============================================================================


class PricePeriodSummary(Base):
    """A precomputed price rollup for one species in one location and period.

    Keyed by `seafood_item_id` (not pricecatcher_item_id) because the app quotes
    canonical species. Median rather than mean, with p25/p75 for spread, because
    premise prices are skewed by a handful of expensive outlets. The three count
    columns are what `quality_status` is decided from: too few observations,
    premises or distinct days and the row is INSUFFICIENT_DATA and must not be
    displayed.

    `calculation_version` is part of the unique key so a recalculated rollup can
    be loaded and compared alongside the old one before it goes live.
    """

    __tablename__ = "price_period_summary"
    __table_args__ = (
        UniqueConstraint(
            "seafood_item_id",
            "location_id",
            "period_type",
            "period_start",
            "period_end",
            "calculation_version",
        ),
        CheckConstraint(
            "observation_count >= 0", name="price_period_summary_observation_count_check"
        ),
        CheckConstraint("premise_count >= 0", name="price_period_summary_premise_count_check"),
        CheckConstraint(
            "distinct_day_count >= 0", name="price_period_summary_distinct_day_count_check"
        ),
        Index(
            "idx_price_period_summary_lookup",
            "seafood_item_id",
            "location_id",
            "period_type",
            "period_end",
        ),
    )

    price_period_summary_id: Mapped[uuid.UUID] = _uuid_pk()
    seafood_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("seafood_item.seafood_item_id"), nullable=False
    )
    location_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("location.location_id"), nullable=False
    )
    source_snapshot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("source_snapshot.source_snapshot_id"), nullable=False
    )
    location_level: Mapped[LocationLevel] = mapped_column(
        _pg_enum(LocationLevel, "location_level_enum"), nullable=False
    )
    period_type: Mapped[PeriodType] = mapped_column(
        _pg_enum(PeriodType, "period_type_enum"), nullable=False
    )
    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    median_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    average_price: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    min_price: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    max_price: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    p25_price: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    p75_price: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    observation_count: Mapped[int] = mapped_column(Integer, nullable=False)
    premise_count: Mapped[int] = mapped_column(Integer, nullable=False)
    distinct_day_count: Mapped[int] = mapped_column(Integer, nullable=False)
    quality_status: Mapped[PriceQuality] = mapped_column(
        _pg_enum(PriceQuality, "price_quality_enum"), nullable=False
    )
    calculation_version: Mapped[str] = mapped_column(Text, nullable=False)
    calculated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    seafood: Mapped[SeafoodItem] = relationship()
    location: Mapped[Location] = relationship()


class PriceTrendPoint(Base):
    """One weekly median — the sparkline behind a price card, keyed by species."""

    __tablename__ = "price_trend_point"
    __table_args__ = (
        UniqueConstraint(
            "seafood_item_id", "location_id", "week_start", "calculation_version"
        ),
        CheckConstraint(
            "observation_count >= 0", name="price_trend_point_observation_count_check"
        ),
        CheckConstraint("premise_count >= 0", name="price_trend_point_premise_count_check"),
        CheckConstraint("active_days >= 0", name="price_trend_point_active_days_check"),
        Index("idx_price_trend_lookup", "seafood_item_id", "location_id", "week_start"),
    )

    price_trend_point_id: Mapped[uuid.UUID] = _uuid_pk()
    seafood_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("seafood_item.seafood_item_id"), nullable=False
    )
    location_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("location.location_id"), nullable=False
    )
    source_snapshot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("source_snapshot.source_snapshot_id"), nullable=False
    )
    week_start: Mapped[date] = mapped_column(Date, nullable=False)
    weekly_median_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    observation_count: Mapped[int] = mapped_column(Integer, nullable=False)
    premise_count: Mapped[int] = mapped_column(Integer, nullable=False)
    active_days: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    quality_status: Mapped[PriceQuality] = mapped_column(
        _pg_enum(PriceQuality, "price_quality_enum"), nullable=False
    )
    calculation_version: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )

    seafood: Mapped[SeafoodItem] = relationship()
    location: Mapped[Location] = relationship()


# =============================================================================
# 12. forecast_model_version  /  13. price_forecast
# =============================================================================


class ForecastModelVersion(Base):
    """A trained price-forecast model version with validation metrics.

    For the deployed engine `algorithm` is MODEL_SELECTION_V1 — a selection
    POLICY, not one estimator. Which estimator won for a given fish is recorded
    on the individual forecast row as `PriceForecast.model_used`, because the
    walk-forward comparison is run per series.
    """

    __tablename__ = "forecast_model_version"
    __table_args__ = (
        CheckConstraint(
            "interval_level IS NULL OR "
            "(interval_level > 0 AND interval_level < 1)",
            name="forecast_model_version_interval_level_check",
        ),
    )

    forecast_model_version_id: Mapped[uuid.UUID] = _uuid_pk()
    version_name: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    algorithm: Mapped[str] = mapped_column(Text, nullable=False)
    target_definition: Mapped[str | None] = mapped_column(Text, nullable=True)
    training_window_start: Mapped[date | None] = mapped_column(Date, nullable=True)
    training_window_end: Mapped[date | None] = mapped_column(Date, nullable=True)
    validation_mae: Mapped[Decimal | None] = mapped_column(Numeric(12, 4), nullable=True)
    validation_rmse: Mapped[Decimal | None] = mapped_column(Numeric(12, 4), nullable=True)
    validation_mape: Mapped[Decimal | None] = mapped_column(Numeric(12, 4), nullable=True)
    interval_level: Mapped[Decimal | None] = mapped_column(Numeric(5, 4), nullable=True)
    configuration: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )


class PriceForecast(Base):
    """Model-generated price outlook — separate from observed PriceCatcher data.

    Mirrors v3_initial_schema.sql plus the additive columns in
    v3_forecast_contract.sql (Step 33B).

    `outlook` and `range_outlook` are two different readings and are stored
    separately on purpose. `outlook` is the directional verdict, emitted only
    when validated evidence clears an RM0.25 movement threshold;
    NO_STRONG_SIGNAL means the evidence did not justify claiming a move, which
    is not the same as predicting stability. `range_outlook` says where the
    forecast band sits against the reference price. Most production fish carry
    NO_STRONG_SIGNAL, and the UI must present that as a real answer.
    """

    __tablename__ = "price_forecast"
    __table_args__ = (
        UniqueConstraint(
            "seafood_item_id",
            "location_id",
            "forecast_model_version_id",
            "forecast_week_start",
        ),
        CheckConstraint(
            "lower_bound <= expected_price AND expected_price <= upper_bound",
            name="price_forecast_bounds_check",
        ),
        CheckConstraint(
            "outlook IS NULL OR outlook IN "
            "('LIKELY_INCREASE', 'LIKELY_DECREASE', 'NO_STRONG_SIGNAL')",
            name="price_forecast_outlook_check",
        ),
        CheckConstraint(
            "quality_status IS NULL OR quality_status IN ('VALID', 'SPARSE_DATA')",
            name="price_forecast_quality_status_check",
        ),
        CheckConstraint(
            "horizon_weeks IS NULL OR horizon_weeks > 0",
            name="price_forecast_horizon_weeks_check",
        ),
        CheckConstraint(
            "current_reference_price IS NULL OR current_reference_price > 0",
            name="price_forecast_reference_price_check",
        ),
        Index(
            "idx_price_forecast_item_location_week",
            "seafood_item_id",
            "location_id",
            "forecast_week_start",
        ),
    )

    price_forecast_id: Mapped[uuid.UUID] = _uuid_pk()
    seafood_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("seafood_item.seafood_item_id"), nullable=False
    )
    location_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("location.location_id"), nullable=False
    )
    forecast_model_version_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("forecast_model_version.forecast_model_version_id"),
        nullable=False,
    )
    # Nullable because the column was added to a table that already existed.
    # The ingester always sets it; a forecast with no traceable snapshot is a
    # number nobody can audit.
    source_snapshot_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("source_snapshot.source_snapshot_id"), nullable=True
    )
    forecast_origin_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    forecast_week_start: Mapped[date] = mapped_column(Date, nullable=False)
    horizon_weeks: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    current_reference_price: Mapped[Decimal | None] = mapped_column(
        Numeric(12, 2), nullable=True
    )
    expected_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    lower_bound: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    upper_bound: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    outlook: Mapped[str | None] = mapped_column(Text, nullable=True)
    range_outlook: Mapped[str | None] = mapped_column(Text, nullable=True)
    quality_status: Mapped[str | None] = mapped_column(Text, nullable=True)
    model_used: Mapped[str | None] = mapped_column(Text, nullable=True)
    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("now()")
    )

    seafood: Mapped[SeafoodItem] = relationship()
    location: Mapped[Location] = relationship()
    forecast_model_version: Mapped[ForecastModelVersion] = relationship()
    snapshot: Mapped[SourceSnapshot | None] = relationship()


# =============================================================================
# 14. supply_landing_point
# =============================================================================


class SupplyLandingPoint(Base):
    """Monthly fish landings, national / coast / state.

    Supply CONTEXT only. There is no species dimension here on purpose — the
    published landings data is not species-resolved, and presenting it as though
    it were would be a fabricated forecast.
    """

    __tablename__ = "supply_landing_point"
    __table_args__ = (
        UniqueConstraint("source_snapshot_id", "period_month", "coast_code", "state_name"),
        CheckConstraint(
            "scope_level IN ('NATIONAL', 'COAST', 'COAST_STATE')",
            name="supply_landing_point_scope_level_check",
        ),
        CheckConstraint(
            "coast_code IN ('all', 'east', 'west', 'borneo')",
            name="supply_landing_point_coast_code_check",
        ),
        CheckConstraint("landings_mt >= 0", name="supply_landing_point_landings_mt_check"),
        CheckConstraint(
            "period_month = date_trunc('month', period_month)::date",
            name="supply_landing_point_period_month_check",
        ),
        Index("idx_supply_landing_period", "period_month", "scope_level", "state_name"),
    )

    supply_landing_point_id: Mapped[uuid.UUID] = _uuid_pk()
    source_snapshot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("source_snapshot.source_snapshot_id"), nullable=False
    )
    period_month: Mapped[date] = mapped_column(Date, nullable=False)
    scope_level: Mapped[str] = mapped_column(Text, nullable=False)
    coast_code: Mapped[str] = mapped_column(Text, nullable=False)
    state_name: Mapped[str] = mapped_column(Text, nullable=False)
    landings_mt: Mapped[Decimal] = mapped_column(Numeric(14, 3), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


# =============================================================================
# 15. cooking_method  /  16. cooking_suitability
# =============================================================================


class CookingMethod(Base):
    """The controlled cooking vocabulary behind GET /cooking/{method}."""

    __tablename__ = "cooking_method"

    cooking_method_id: Mapped[uuid.UUID] = _uuid_pk()
    code: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    name_en: Mapped[str] = mapped_column(Text, nullable=False)
    name_ms: Mapped[str | None] = mapped_column(Text, nullable=True)
    description_en: Mapped[str | None] = mapped_column(Text, nullable=True)

    suitability: Mapped[list[CookingSuitability]] = relationship(back_populates="method")


class CookingSuitability(Base):
    """How well one species suits one cooking method, 1-5, with a reason.

    Team-curated rather than sourced, which is why `source_snapshot_id` is
    nullable here and points at the curation snapshot when set — the app must be
    able to say "our recommendation" instead of implying external authority.
    """

    __tablename__ = "cooking_suitability"
    __table_args__ = (
        UniqueConstraint("seafood_item_id", "cooking_method_id"),
        CheckConstraint(
            "suitability_score BETWEEN 1 AND 5", name="cooking_suitability_score_check"
        ),
        Index("idx_cooking_suitability_item", "seafood_item_id"),
        Index("idx_cooking_suitability_method_score", "cooking_method_id", "suitability_score"),
    )

    cooking_suitability_id: Mapped[uuid.UUID] = _uuid_pk()
    seafood_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("seafood_item.seafood_item_id"), nullable=False
    )
    cooking_method_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cooking_method.cooking_method_id"), nullable=False
    )
    source_snapshot_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("source_snapshot.source_snapshot_id"), nullable=True
    )
    suitability_score: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    reason_en: Mapped[str] = mapped_column(Text, nullable=False)
    reason_ms: Mapped[str | None] = mapped_column(Text, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    seafood: Mapped[SeafoodItem] = relationship(back_populates="cooking_suitability")
    method: Mapped[CookingMethod] = relationship(back_populates="suitability")


# =============================================================================
# 17. cv_model_version  /  18. cv_class_mapping
# =============================================================================


class CvModelVersion(Base):
    """A deployed computer-vision model.

    `input_contract` and `metrics` are JSONB because they evolve with each model
    without a migration. `confidence_threshold` is stored per model, not in
    application config, so swapping the model swaps its threshold atomically.
    """

    __tablename__ = "cv_model_version"
    __table_args__ = (
        CheckConstraint(
            "confidence_threshold IS NULL OR "
            "(confidence_threshold >= 0 AND confidence_threshold <= 1)",
            name="cv_model_version_confidence_threshold_check",
        ),
    )

    cv_model_version_id: Mapped[uuid.UUID] = _uuid_pk()
    version_name: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    input_contract: Mapped[dict] = mapped_column(JSONB, nullable=False)
    metrics: Mapped[dict] = mapped_column(JSONB, nullable=False)
    confidence_threshold: Mapped[Decimal | None] = mapped_column(Numeric(5, 4), nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    class_mappings: Mapped[list[CvClassMapping]] = relationship(back_populates="cv_model_version")


class CvClassMapping(Base):
    """Maps a model class label/index to a canonical seafood_item row."""

    __tablename__ = "cv_class_mapping"
    __table_args__ = (
        UniqueConstraint("cv_model_version_id", "model_class_label"),
        UniqueConstraint("cv_model_version_id", "model_class_index", name="uq_cv_class_mapping_index"),
    )

    cv_class_mapping_id: Mapped[uuid.UUID] = _uuid_pk()
    cv_model_version_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("cv_model_version.cv_model_version_id"),
        nullable=False,
    )
    seafood_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("seafood_item.seafood_item_id"), nullable=False
    )
    model_class_label: Mapped[str] = mapped_column(Text, nullable=False)
    model_class_index: Mapped[int] = mapped_column(Integer, nullable=False)

    cv_model_version: Mapped[CvModelVersion] = relationship(back_populates="class_mappings")
    seafood: Mapped[SeafoodItem] = relationship()


# =============================================================================
# 19-21. recipe and its bridges
# =============================================================================


class Recipe(Base):
    """An imported recipe. Ingredients and instructions stay as JSONB because
    their shape is the source's, not ours, and normalising them would lose
    information we cannot reconstruct."""

    __tablename__ = "recipe"
    __table_args__ = (
        CheckConstraint(
            "prep_time_minutes IS NULL OR prep_time_minutes >= 0",
            name="recipe_prep_time_minutes_check",
        ),
        CheckConstraint(
            "cook_time_minutes IS NULL OR cook_time_minutes >= 0",
            name="recipe_cook_time_minutes_check",
        ),
        CheckConstraint(
            "total_time_minutes IS NULL OR total_time_minutes >= 0",
            name="recipe_total_time_minutes_check",
        ),
        CheckConstraint("servings IS NULL OR servings > 0", name="recipe_servings_check"),
    )

    recipe_id: Mapped[uuid.UUID] = _uuid_pk()
    source_snapshot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("source_snapshot.source_snapshot_id"), nullable=False
    )
    external_recipe_id: Mapped[str] = mapped_column(Text, nullable=False)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    ingredients_json: Mapped[dict] = mapped_column(JSONB, nullable=False)
    instructions_json: Mapped[dict] = mapped_column(JSONB, nullable=False)
    prep_time_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cook_time_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    total_time_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    servings: Mapped[Decimal | None] = mapped_column(Numeric(8, 2), nullable=True)
    cuisine: Mapped[str | None] = mapped_column(Text, nullable=True)
    nutrition_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    source_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    seafood_mappings: Mapped[list[RecipeSeafoodMapping]] = relationship(
        back_populates="recipe"
    )
    cooking_methods: Mapped[list[RecipeCookingMethod]] = relationship(back_populates="recipe")


class RecipeSeafoodMapping(Base):
    """Which species a recipe is for, and how confidently it was matched."""

    __tablename__ = "recipe_seafood_mapping"
    __table_args__ = (
        UniqueConstraint("recipe_id", "seafood_item_id"),
        Index("idx_recipe_seafood_mapping_seafood", "seafood_item_id"),
    )

    recipe_seafood_mapping_id: Mapped[uuid.UUID] = _uuid_pk()
    recipe_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("recipe.recipe_id"), nullable=False
    )
    seafood_item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("seafood_item.seafood_item_id"), nullable=False
    )
    mapping_type: Mapped[RecipeMappingType] = mapped_column(
        _pg_enum(RecipeMappingType, "recipe_mapping_type_enum"), nullable=False
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    recipe: Mapped[Recipe] = relationship(back_populates="seafood_mappings")
    seafood: Mapped[SeafoodItem] = relationship(back_populates="recipe_mappings")


class RecipeCookingMethod(Base):
    """Which cooking methods a recipe uses. `source_method_text` keeps the
    original phrasing ("bakar dalam ketuhar") next to the mapped code."""

    __tablename__ = "recipe_cooking_method"
    __table_args__ = (
        UniqueConstraint("recipe_id", "cooking_method_id"),
        Index("idx_recipe_cooking_method_method", "cooking_method_id"),
    )

    recipe_cooking_method_id: Mapped[uuid.UUID] = _uuid_pk()
    recipe_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("recipe.recipe_id"), nullable=False
    )
    cooking_method_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cooking_method.cooking_method_id"), nullable=False
    )
    source_method_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    recipe: Mapped[Recipe] = relationship(back_populates="cooking_methods")


class AppUser(Base):
    """Mobile app account stored in PostgreSQL (not Firebase/Firestore)."""

    __tablename__ = "app_user"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )
    name: Mapped[str] = mapped_column(Text, nullable=False)
    email: Mapped[str] = mapped_column(Text, nullable=False)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=text("now()"),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=text("now()"),
    )


__all__ = [
    "AggregationRule",
    "AppUser",
    "Base",
    "CollectionMethod",
    "CookingMethod",
    "CookingSuitability",
    "CvClassMapping",
    "CvModelVersion",
    "DataSource",
    "ForecastModelVersion",
    "Location",
    "LocationLevel",
    "MappingConfidence",
    "PeriodType",
    "PriceCatcherItem",
    "PriceCatcherPremise",
    "PriceForecast",
    "PriceItemMapping",
    "PriceMappingType",
    "PricePeriodSummary",
    "PriceQuality",
    "PriceTrendPoint",
    "ProductForm",
    "Recipe",
    "RecipeCookingMethod",
    "RecipeMappingType",
    "RecipeSeafoodMapping",
    "SeafoodAlias",
    "SeafoodAliasType",
    "SeafoodItem",
    "SourceSnapshot",
    "SupplyLandingPoint",
    "SustainabilityRating",
    "WwfAssessment",
]
