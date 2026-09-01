"""Account favourites and preferred forecast location.

Revision ID: 0005_user_prefs
Revises: 0004_forecast_contract
Create Date: 2026-09-01

Executes db/schema/v3_user_prefs.sql. The SQL file is the source of truth.
"""

from collections.abc import Sequence
from pathlib import Path

from alembic import op

revision: str = "0005_user_prefs"
down_revision: str | None = "0004_forecast_contract"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SCHEMA_FILE = Path(__file__).resolve().parents[2] / "db" / "schema" / "v3_user_prefs.sql"


def _run_sql_file(path: Path) -> None:
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
    op.execute("DROP TABLE IF EXISTS user_favourite")
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS preferred_location_id")
