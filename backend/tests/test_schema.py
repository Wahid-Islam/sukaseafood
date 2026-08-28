"""Structural tests — the database itself, not the API over it."""

import asyncio

import pytest
from sqlalchemy import text

from app.database import engine

EXPECTED_TABLES = {
    "location", "seafood_item", "seafood_alias", "data_source", "source_snapshot",
    "wwf_assessment", "pricecatcher_item", "price_item_mapping", "price_summary",
    "price_trend_point", "supply_landing_point", "cooking_method",
    "cooking_suitability", "cv_model_version", "recipe", "recipe_seafood_mapping",
    "recipe_cooking_method", "app_user",
}

EXPECTED_ENUMS = {
    "location_level_enum", "seafood_alias_type_enum", "collection_method_enum",
    "sustainability_rating_enum", "product_form_enum", "price_mapping_type_enum",
    "price_quality_enum", "recipe_mapping_type_enum",
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


def test_all_8_enums_exist():
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
    """UNDETERMINED must stay un-representable as a rating.

    If someone adds it to the enum, an unassessed species could be stored as
    'undetermined' instead of having no row — and the distinction between
    'we checked and it's unclear' and 'we never checked' would be lost.
    """
    rows = _fetch(
        "SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid "
        "WHERE t.typname = 'sustainability_rating_enum'"
    )
    assert {r[0] for r in rows} == {"BEST_CHOICE", "REDUCE", "AVOID"}


def test_suka_uuid5_matches_python_uuid5():
    """SQL seeds and Python ETL must agree on primary keys."""
    import uuid

    namespace = uuid.UUID("6f9619ff-8b86-d011-b42d-00c04fc964ff")
    for key in ("seafood_item:SF001", "location:Johor", "cooking_method:GRILL"):
        rows = _fetch("SELECT suka_uuid5(:k)", k=key)
        assert str(rows[0][0]) == str(uuid.uuid5(namespace, key)), key


def test_alias_uniqueness_is_case_insensitive():
    """Two aliases differing only in case are the same alias."""
    rows = _fetch(
        "SELECT seafood_item_id, lower(trim(alias_name)) a, COUNT(*) "
        "FROM seafood_alias GROUP BY 1, 2 HAVING COUNT(*) > 1"
    )
    assert rows == []


def test_price_summary_rejects_an_unsupported_window():
    """window_days is constrained to the two windows the product defines."""
    from sqlalchemy.exc import IntegrityError

    async def run():
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "INSERT INTO price_summary ("
                    " price_summary_id, pricecatcher_item_id, location_id,"
                    " source_snapshot_id, location_level, window_days, period_start,"
                    " period_end, median_price, observation_count, premise_count,"
                    " distinct_day_count, quality_status, calculation_version, calculated_at"
                    ") VALUES ("
                    " gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),"
                    " gen_random_uuid(), 'STATE', 45, '2026-01-01', '2026-02-14',"
                    " 10.00, 1, 1, 1, 'DISPLAYABLE', 'v1', now())"
                )
            )

    with pytest.raises(IntegrityError):
        asyncio.run(run())


def test_no_orphaned_rows_after_seed():
    rows = _fetch(
        "SELECT COUNT(*) FROM seafood_alias a "
        "LEFT JOIN seafood_item s USING (seafood_item_id) "
        "WHERE s.seafood_item_id IS NULL"
    )
    assert rows[0][0] == 0
