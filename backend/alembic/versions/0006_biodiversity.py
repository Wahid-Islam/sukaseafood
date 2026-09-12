"""Biodiversity profile and OBIS occurrence tables.

Revision ID: 0006_biodiversity
Revises: 0005_user_prefs
Create Date: 2026-09-12

Executes db/schema/v3_biodiversity.sql. The SQL file is the source of truth.
"""

from collections.abc import Sequence
from pathlib import Path

from alembic import op

revision: str = "0006_biodiversity"
down_revision: str | None = "0005_user_prefs"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SCHEMA_FILE = Path(__file__).resolve().parents[2] / "db" / "schema" / "v3_biodiversity.sql"


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
    op.execute("DROP TABLE IF EXISTS biodiversity_occurrence")
    op.execute("DROP TABLE IF EXISTS biodiversity_profile")
