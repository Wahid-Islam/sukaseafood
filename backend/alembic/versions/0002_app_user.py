"""Add app_user table for email/password accounts in PostgreSQL.

Revision ID: 0002_app_user
Revises: 0001_i1_initial_schema
Create Date: 2026-08-28
"""

from collections.abc import Sequence
from pathlib import Path

from alembic import op

revision: str = "0002_app_user"
down_revision: str | None = "0001_i1_initial_schema"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

DB_DIR = Path(__file__).resolve().parents[2] / "db"


def upgrade() -> None:
    path = DB_DIR / "schema" / "i1_app_user.sql"
    sql = path.read_text(encoding="utf-8")
    lines = [
        line
        for line in sql.splitlines()
        if line.strip().upper() not in {"BEGIN;", "COMMIT;"}
    ]
    op.execute("\n".join(lines))


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS app_user CASCADE;")
