"""Structural tests — the database itself, not the API over it."""

import asyncio

import pytest
from sqlalchemy import text

from app.database import engine

EXPECTED_TABLES = {
    "location", "seafood_item", "seafood_alias", "data_source", "source_snapshot",
    "wwf_assessment", "pricecatcher_item", "pricecatcher_premise",
    "price_item_mapping", "price_period_summary", "price_trend_point",
    "forecast_model_version", "price_forecast", "supply_landing_point",
    "cooking_method", "cooking_suitability", "cv_model_version", "cv_class_mapping",
    "recipe", "recipe_seafood_mapping", "recipe_cooking_method", "app_user",
    "user_favourite",
}

EXPECTED_ENUMS = {
    "location_level_enum", "seafood_alias_type_enum", "collection_method_enum",
    "sustainability_rating_enum", "product_form_enum", "price_mapping_type_enum",
    "aggregation_rule_enum", "mapping_confidence_enum", "price_quality_enum",
    "period_type_enum", "recipe_mapping_type_enum",
}


def _fetch(sql: str, **params):
    async def run():
        async with engine.connect() as conn:
            return (await conn.execute(text(sql), params)).all()

    return asyncio.run(run())


def test_all_expected_tables_exist():
    rows = _fetch(
        "SELECT table_name FROM information_schema.tables WHERE table_schema='public'"
    )
    assert EXPECTED_TABLES <= {r[0] for r in rows}


def test_all_v3_enums_exist():
    rows = _fetch(
        "SELECT typname FROM pg_type WHERE typnamespace='public'::regnamespace AND typtype='e'"
    )
    assert EXPECTED_ENUMS <= {r[0] for r in rows}


def test_orm_models_cover_every_table():
    """Guards against a table being added to the SQL but not the ORM."""
    import app.models  # noqa: F401
    from app.database import Base

    assert {t.name for t in Base.metadata.sorted_tables} == EXPECTED_TABLES


def test_sustainability_enum_has_no_undetermined_member():
    rows = _fetch(
        "SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid "
        "WHERE t.typname = 'sustainability_rating_enum'"
    )
    assert {r[0] for r in rows} == {"BEST_CHOICE", "REDUCE", "AVOID"}


def test_suka_uuid5_matches_python_uuid5():
    import uuid

    namespace = uuid.UUID("6f9619ff-8b86-d011-b42d-00c04fc964ff")
    for key in ("seafood_item:SF001", "location:Johor", "cooking_method:GRILL"):
        rows = _fetch("SELECT suka_uuid5(:k)", k=key)
        assert str(rows[0][0]) == str(uuid.uuid5(namespace, key)), key


def test_alias_uniqueness_is_case_insensitive():
    rows = _fetch(
        "SELECT seafood_item_id, lower(trim(alias_name)) a, COUNT(*) "
        "FROM seafood_alias GROUP BY 1, 2 HAVING COUNT(*) > 1"
    )
    assert rows == []


def test_price_period_summary_requires_period_type():
    """period_type is constrained to the V3 enum (WEEK/MONTH/QUARTER)."""
    from sqlalchemy.exc import DBAPIError, IntegrityError

    async def run():
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "INSERT INTO price_period_summary ("
                    " price_period_summary_id, seafood_item_id, location_id,"
                    " source_snapshot_id, location_level, period_type, period_start,"
                    " period_end, median_price, observation_count, premise_count,"
                    " distinct_day_count, quality_status, calculation_version, calculated_at"
                    ") VALUES ("
                    " gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),"
                    " gen_random_uuid(), 'STATE', 'YEAR', '2026-01-01', '2026-12-31',"
                    " 10.00, 1, 1, 1, 'DISPLAYABLE', 'v1', now())"
                )
            )

    with pytest.raises((IntegrityError, DBAPIError)):
        asyncio.run(run())


def test_seafood_item_has_v3_presentation_fields():
    rows = _fetch(
        "SELECT COUNT(*) FROM seafood_item "
        "WHERE fish_type IS NULL OR description IS NULL OR taxonomic_level IS NULL"
    )
    assert rows[0][0] == 0


def test_no_orphaned_rows_after_seed():
    rows = _fetch(
        "SELECT COUNT(*) FROM seafood_alias a "
        "LEFT JOIN seafood_item s USING (seafood_item_id) "
        "WHERE s.seafood_item_id IS NULL"
    )
    assert rows[0][0] == 0


def test_i1_price_summary_table_is_gone():
    rows = _fetch(
        "SELECT COUNT(*) FROM information_schema.tables "
        "WHERE table_schema='public' AND table_name='price_summary'"
    )
    assert rows[0][0] == 0


# --- forecast contract (Step 33B) -------------------------------------------

FORECAST_COLUMNS = {
    "source_snapshot_id",
    "forecast_origin_date",
    "horizon_weeks",
    "current_reference_price",
    "range_outlook",
    "quality_status",
    "model_used",
}


def test_price_forecast_has_engine_columns():
    """v3_forecast_contract.sql must have been applied, not just V3."""
    rows = _fetch(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_schema='public' AND table_name='price_forecast'"
    )
    assert FORECAST_COLUMNS <= {r[0] for r in rows}


def test_price_forecast_rejects_stable_outlook():
    """STABLE is not a valid outlook, and the database is what enforces it.

    The engine's three directional values are deliberate: NO_STRONG_SIGNAL
    means "no validated evidence of a move", which is a weaker claim than
    predicting the price will hold. Allowing STABLE in would let a well-meaning
    ingestion script quietly upgrade uncertainty into a prediction.
    """
    from sqlalchemy.exc import DBAPIError, IntegrityError

    async def run():
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "INSERT INTO price_forecast ("
                    " price_forecast_id, seafood_item_id, location_id,"
                    " forecast_model_version_id, forecast_week_start,"
                    " expected_price, lower_bound, upper_bound, outlook"
                    ") SELECT gen_random_uuid(), pf.seafood_item_id, pf.location_id,"
                    " pf.forecast_model_version_id, DATE '2099-01-04',"
                    " 10.00, 9.00, 11.00, 'STABLE'"
                    " FROM price_forecast pf LIMIT 1"
                )
            )

    with pytest.raises((IntegrityError, DBAPIError)):
        asyncio.run(run())


def test_exactly_one_active_forecast_model_version():
    """Two active versions would make the served forecast depend on row order."""
    rows = _fetch("SELECT COUNT(*) FROM forecast_model_version WHERE active")
    assert rows[0][0] == 1


def test_every_forecast_fish_has_the_full_horizon():
    """A fish with fewer than four weeks renders a truncated chart silently."""
    rows = _fetch(
        "SELECT pf.seafood_item_id, COUNT(*) FROM price_forecast pf "
        "JOIN forecast_model_version mv USING (forecast_model_version_id) "
        "WHERE mv.active GROUP BY 1 HAVING COUNT(*) <> 4"
    )
    assert rows == []


def test_forecast_rows_are_traceable():
    """Every served forecast points at the snapshot that produced it."""
    rows = _fetch(
        "SELECT COUNT(*) FROM price_forecast pf "
        "JOIN forecast_model_version mv USING (forecast_model_version_id) "
        "WHERE mv.active AND pf.source_snapshot_id IS NULL"
    )
    assert rows[0][0] == 0


def test_forecast_quality_status_is_from_the_production_vocabulary():
    rows = _fetch(
        "SELECT DISTINCT quality_status FROM price_forecast WHERE quality_status IS NOT NULL"
    )
    assert {r[0] for r in rows} <= {"VALID", "SPARSE_DATA"}
