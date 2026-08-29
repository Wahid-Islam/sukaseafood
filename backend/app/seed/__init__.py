"""Apply the SQL reference seed from Python.

The seed itself lives in backend/db/seed/*.sql, not in Python dictionaries. One
definition of the reference data, usable three ways:

    backend/db/apply.sh          shell / CI / Supabase
    docker-entrypoint-initdb.d   automatic on a fresh Docker volume
    apply_seed()                 tests and one-off local resets

Everything is idempotent, so calling this against a seeded database is a no-op
that costs a few UPDATEs.

Note the raw-driver call below: these files contain multiple statements and
dollar-quoted function bodies, which asyncpg only accepts through its simple
query protocol. SQLAlchemy's exec_driver_sql would try to prepare them and fail.
"""

from __future__ import annotations

import logging
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.database import engine as default_engine
from app.models import SeafoodItem

logger = logging.getLogger(__name__)

# backend/app/seed/ -> backend/db
DB_DIR = Path(__file__).resolve().parents[2] / "db"
SCHEMA_DIR = DB_DIR / "schema"
SEED_DIR = DB_DIR / "seed"


async def _execute_file(engine: AsyncEngine, path: Path) -> None:
    sql = path.read_text(encoding="utf-8")
    async with engine.begin() as conn:
        raw = await conn.get_raw_connection()
        await raw.driver_connection.execute(sql)


async def apply_schema(engine: AsyncEngine | None = None) -> None:
    """Create the V3 tables, enums, functions, indexes and app_user. Idempotent."""
    engine = engine or default_engine
    for name in (
        "v3_initial_schema.sql",
        "v3_migrate_from_i1.sql",
        "v3_functions_indexes.sql",
        "i1_app_user.sql",
    ):
        path = SCHEMA_DIR / name
        logger.info("Applying schema file %s", path.name)
        await _execute_file(engine, path)


async def apply_seed(engine: AsyncEngine | None = None) -> None:
    """Load reference data in filename order. Idempotent."""
    engine = engine or default_engine
    for path in sorted(SEED_DIR.glob("*.sql")):
        logger.info("Applying seed file %s", path.name)
        await _execute_file(engine, path)


async def seed_database(session: AsyncSession) -> None:
    """Seed only if the canonical species table is empty.

    In any shared environment the schema and seed are applied by migrations
    before the process starts, so this is normally a single SELECT that finds
    rows and returns.
    """
    if await session.scalar(select(SeafoodItem).limit(1)) is not None:
        return
    logger.warning("seafood_item is empty — applying reference seed.")
    await apply_seed()


__all__ = ["apply_schema", "apply_seed", "seed_database"]
