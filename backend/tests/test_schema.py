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
