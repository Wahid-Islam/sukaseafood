"""I1 initial schema — 17 tables, 8 enums, functions and indexes.

Revision ID: 0001_i1_initial_schema
Revises:
Create Date: 2026-08-26

This revision EXECUTES backend/db/schema/*.sql rather than rebuilding the schema
with op.create_table() calls. That is intentional:

  * the SQL file is the artifact the team reviewed and the one applied directly
    to Cloud SQL, so it must stay the single definition of the schema
  * expression indexes, partial unique indexes and the suka_uuid5() function all
    round-trip through Alembic's autogenerate imperfectly
  * a second ORM-derived definition of the same tables would drift from the
    first the moment anyone edited one and not the other

Later revisions SHOULD use normal op.* operations. This one only exists to get a
fresh database to the reviewed baseline.
"""

from collections.abc import Sequence
from pathlib import Path

from alembic import op

revision: str = "0001_i1_initial_schema"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# backend/alembic/versions/ -> backend/db
DB_DIR = Path(__file__).resolve().parents[2] / "db"

SCHEMA_FILES = (
    DB_DIR / "schema" / "i1_initial_schema.sql",
    DB_DIR / "schema" / "i1_functions_indexes.sql",
)

TABLES = (
    "recipe_cooking_method",
    "recipe_seafood_mapping",
    "recipe",
    "cv_model_version",
    "cooking_suitability",
    "cooking_method",
    "supply_landing_point",
    "price_trend_point",
    "price_summary",
    "price_item_mapping",
    "pricecatcher_item",
    "wwf_assessment",
    "source_snapshot",
    "data_source",
    "seafood_alias",
    "seafood_item",
    "location",
)

ENUMS = (
    "recipe_mapping_type_enum",
    "price_quality_enum",
    "price_mapping_type_enum",
    "product_form_enum",
    "sustainability_rating_enum",
    "collection_method_enum",
    "seafood_alias_type_enum",
    "location_level_enum",
)


def _run_sql_file(path: Path) -> None:
    """Execute one .sql file.

    BEGIN/COMMIT are stripped because Alembic already opened a transaction;
    leaving them in would commit mid-migration and break rollback on failure.
    """
    sql = path.read_text(encoding="utf-8")
    lines = [
        line
        for line in sql.splitlines()
        if line.strip().upper() not in {"BEGIN;", "COMMIT;"}
    ]
    op.execute("\n".join(lines))


def upgrade() -> None:
    for path in SCHEMA_FILES:
        if not path.exists():
            raise FileNotFoundError(
                f"Schema file missing: {path}. The migration reads the SQL in "
                "backend/db/schema/; it is not vendored into this revision."
            )
        _run_sql_file(path)


def downgrade() -> None:
    # Ordered children-first so foreign keys never block a drop.
    for table in TABLES:
        op.execute(f"DROP TABLE IF EXISTS {table} CASCADE")
    for enum in ENUMS:
        op.execute(f"DROP TYPE IF EXISTS {enum}")
    op.execute("DROP FUNCTION IF EXISTS suka_uuid5(TEXT)")
