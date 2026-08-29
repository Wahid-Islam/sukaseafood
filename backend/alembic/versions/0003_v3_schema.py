"""Upgrade I1 schema to V3 (canonical seafood hub + derived price layer).

Revision ID: 0003_v3_schema
Revises: 0002_app_user
Create Date: 2026-08-29

Executes the reviewed V3 DDL and the I1→V3 migrate script so both fresh and
existing databases end on the same contract. SQL remains the source of truth;
this revision only applies those files.
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
    # V3 → I1 is not supported; Cloud SQL and local DBs should reset instead.
    raise NotImplementedError(
        "Downgrade from V3 is not supported. Recreate the database from I1 "
        "revisions or re-apply backend/db/schema if you need a clean slate."
    )
