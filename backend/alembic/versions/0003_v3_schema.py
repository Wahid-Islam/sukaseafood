"""Upgrade I1 schema to V3 (canonical seafood hub + derived price layer).

Revision ID: 0003_v3_schema
Revises: 0002_app_user
Create Date: 2026-08-29

Executes the reviewed V3 DDL and the I1→V3 migrate script so both fresh and
existing databases end on the same contract. SQL remains the source of truth;
this revision only applies those files.

Downgrade restores the I1 domain shape (minus app_user, which belongs to 0002)
so CI can round-trip `alembic downgrade base` / `upgrade head`.
"""

from collections.abc import Sequence
from pathlib import Path

from alembic import op

revision: str = "0003_v3_schema"
down_revision: str | None = "0002_app_user"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

DB_DIR = Path(__file__).resolve().parents[2] / "db"

SCHEMA_FILES = (
    DB_DIR / "schema" / "v3_initial_schema.sql",
    DB_DIR / "schema" / "v3_migrate_from_i1.sql",
    DB_DIR / "schema" / "v3_functions_indexes.sql",
)


def _run_sql_file(path: Path) -> None:
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
            raise FileNotFoundError(f"Schema file missing: {path}")
        _run_sql_file(path)


def downgrade() -> None:
    # Drop V3-only derived / mapping tables (children first).
    op.execute("DROP TABLE IF EXISTS price_forecast CASCADE")
    op.execute("DROP TABLE IF EXISTS forecast_model_version CASCADE")
    op.execute("DROP TABLE IF EXISTS cv_class_mapping CASCADE")
    op.execute("DROP TABLE IF EXISTS price_period_summary CASCADE")
    op.execute("DROP TABLE IF EXISTS pricecatcher_premise CASCADE")

    # Restore I1 price_trend_point shape (keyed by pricecatcher_item_id).
    op.execute("DROP TABLE IF EXISTS price_trend_point CASCADE")
    op.execute(
        """
        CREATE TABLE price_trend_point (
          price_trend_point_id UUID PRIMARY KEY,
          pricecatcher_item_id UUID NOT NULL
            REFERENCES pricecatcher_item(pricecatcher_item_id),
          location_id UUID NOT NULL REFERENCES location(location_id),
          source_snapshot_id UUID NOT NULL
            REFERENCES source_snapshot(source_snapshot_id),
          location_level location_level_enum NOT NULL,
          week_start DATE NOT NULL,
          weekly_median NUMERIC(12,2) NOT NULL,
          observation_count INTEGER NOT NULL CHECK (observation_count >= 0),
          premise_count INTEGER NOT NULL CHECK (premise_count >= 0),
          quality_status price_quality_enum NOT NULL,
          calculation_version TEXT NOT NULL,
          UNIQUE (
            pricecatcher_item_id,
            location_id,
            week_start,
            calculation_version
          )
        )
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_price_trend_lookup
          ON price_trend_point (pricecatcher_item_id, location_id, week_start DESC)
        """
    )

    # Restore I1 price_summary.
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS price_summary (
          price_summary_id UUID PRIMARY KEY,
          pricecatcher_item_id UUID NOT NULL
            REFERENCES pricecatcher_item(pricecatcher_item_id),
          location_id UUID NOT NULL REFERENCES location(location_id),
          source_snapshot_id UUID NOT NULL
            REFERENCES source_snapshot(source_snapshot_id),
          location_level location_level_enum NOT NULL,
          window_days SMALLINT NOT NULL CHECK (window_days IN (30, 90)),
          period_start DATE NOT NULL,
          period_end DATE NOT NULL,
          median_price NUMERIC(12,2) NOT NULL,
          p25_price NUMERIC(12,2),
          p75_price NUMERIC(12,2),
          observation_count INTEGER NOT NULL CHECK (observation_count >= 0),
          premise_count INTEGER NOT NULL CHECK (premise_count >= 0),
          distinct_day_count INTEGER NOT NULL CHECK (distinct_day_count >= 0),
          quality_status price_quality_enum NOT NULL,
          calculation_version TEXT NOT NULL,
          calculated_at TIMESTAMPTZ NOT NULL,
          UNIQUE (
            pricecatcher_item_id,
            location_id,
            window_days,
            period_end,
            calculation_version
          )
        )
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS idx_price_summary_lookup
          ON price_summary (
            pricecatcher_item_id, location_id, window_days, period_end DESC
          )
        """
    )

    # Drop V3 columns added to existing tables.
    op.execute(
        """
        ALTER TABLE price_item_mapping
          DROP COLUMN IF EXISTS aggregation_rule,
          DROP COLUMN IF EXISTS mapping_confidence
        """
    )
    op.execute(
        """
        ALTER TABLE wwf_assessment
          DROP COLUMN IF EXISTS secondary_common_name_raw,
          DROP COLUMN IF EXISTS context
        """
    )
    op.execute(
        """
        ALTER TABLE seafood_item
          DROP COLUMN IF EXISTS scientific_name_normalized,
          DROP COLUMN IF EXISTS taxonomic_level,
          DROP COLUMN IF EXISTS fish_type,
          DROP COLUMN IF EXISTS description,
          DROP COLUMN IF EXISTS primary_image_url,
          DROP COLUMN IF EXISTS created_at,
          DROP COLUMN IF EXISTS updated_at
        """
    )
    op.execute(
        """
        ALTER TABLE seafood_item
          ADD CONSTRAINT seafood_item_scientific_name_key UNIQUE (scientific_name)
        """
    )
    op.execute("ALTER TABLE cv_model_version DROP COLUMN IF EXISTS active")

    # Restore I1 WWF natural uniqueness.
    op.execute(
        "ALTER TABLE wwf_assessment "
        "DROP CONSTRAINT IF EXISTS wwf_assessment_source_snapshot_id_source_record_key_key"
    )
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_wwf_assessment_natural
          ON wwf_assessment (seafood_item_id, source_snapshot_id, source_record_key)
        """
    )

    # Drop V3-only indexes that may remain after table drops.
    op.execute("DROP INDEX IF EXISTS idx_seafood_item_scientific_normalized")
    op.execute("DROP INDEX IF EXISTS idx_price_period_summary_lookup")
    op.execute("DROP INDEX IF EXISTS idx_price_forecast_lookup")
    op.execute("DROP INDEX IF EXISTS idx_pricecatcher_premise_location")
    op.execute("DROP INDEX IF EXISTS idx_cv_class_mapping_seafood")
    op.execute("DROP INDEX IF EXISTS uq_cv_class_mapping_index")

    # Drop V3 enums (PROXY label on price_mapping_type_enum is left in place —
    # Postgres cannot remove enum labels).
    op.execute("DROP TYPE IF EXISTS period_type_enum")
    op.execute("DROP TYPE IF EXISTS aggregation_rule_enum")
    op.execute("DROP TYPE IF EXISTS mapping_confidence_enum")
