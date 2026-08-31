"""Align price_forecast with the Step 33B forecasting contract.

Revision ID: 0004_forecast_contract
Revises: 0003_v3_schema
Create Date: 2026-08-31

Executes db/schema/v3_forecast_contract.sql. As with 0003, the SQL file is the
source of truth and this revision only applies it.

Downgrade removes the added columns and returns price_forecast to the shape
0003 leaves it in, so CI can round-trip downgrade/upgrade.
"""

from collections.abc import Sequence
from pathlib import Path

from alembic import op

revision: str = "0004_forecast_contract"
down_revision: str | None = "0003_v3_schema"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SCHEMA_FILE = Path(__file__).resolve().parents[2] / "db" / "schema" / "v3_forecast_contract.sql"


def _run_sql_file(path: Path) -> None:
    """Execute a schema file, minus its transaction control.

    Alembic already owns the transaction; a nested BEGIN/COMMIT inside the
    migration would commit half of it early.
    """
    sql = path.read_text(encoding="utf-8")
    lines = [
        line
        for line in sql.splitlines()
        if line.strip().upper() not in {"BEGIN;", "COMMIT;"}
    ]
    op.execute("\n".join(lines))


def upgrade() -> None:
    if not SCHEMA_FILE.exists():
        raise FileNotFoundError(f"Schema file missing: {SCHEMA_FILE}")
    _run_sql_file(SCHEMA_FILE)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS idx_price_forecast_item_location_week")

    for constraint in (
        "price_forecast_outlook_check",
        "price_forecast_quality_status_check",
        "price_forecast_horizon_weeks_check",
        "price_forecast_reference_price_check",
    ):
        op.execute(f"ALTER TABLE price_forecast DROP CONSTRAINT IF EXISTS {constraint}")

    op.execute(
        """
        ALTER TABLE price_forecast
          DROP COLUMN IF EXISTS source_snapshot_id,
          DROP COLUMN IF EXISTS forecast_origin_date,
          DROP COLUMN IF EXISTS horizon_weeks,
          DROP COLUMN IF EXISTS current_reference_price,
          DROP COLUMN IF EXISTS range_outlook,
          DROP COLUMN IF EXISTS quality_status,
          DROP COLUMN IF EXISTS model_used
        """
    )
    op.execute("ALTER TABLE forecast_model_version DROP COLUMN IF EXISTS target_definition")
