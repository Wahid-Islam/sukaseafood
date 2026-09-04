"""Test fixtures.

The tests run against a REAL PostgreSQL database, not SQLite. The V3 schema
depends on enum types, JSONB, expression indexes and partial unique indexes;
a SQLite substitute would pass tests that production would fail.

Point TEST_DATABASE_URL at a scratch database:

    docker compose up -d db
    TEST_DATABASE_URL=postgresql+asyncpg://sukaseafood:sukaseafood@localhost:5432/sukaseafood_test pytest

If no database is reachable the whole suite skips with an explanatory message,
so a contributor without Docker running gets a clear signal instead of 40
identical connection errors.
"""

from __future__ import annotations

import asyncio
import os

import pytest

TEST_DATABASE_URL = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://sukaseafood:sukaseafood@localhost:5432/sukaseafood_test",
)

# Must be set before app.config is imported anywhere.
os.environ["DATABASE_URL"] = TEST_DATABASE_URL
os.environ.setdefault("FIREBASE_ENABLED", "false")

# Each test gets its own event loop (asyncio.run, or TestClient's portal), and a
# pooled asyncpg connection cannot cross loops. NullPool makes every connection
# local to the loop that opens it.
os.environ["DB_USE_NULL_POOL"] = "true"


def _database_available() -> bool:
    from app.database import ping

    try:
        return asyncio.run(ping())
    except Exception:  # noqa: BLE001
        return False


@pytest.fixture(scope="session", autouse=True)
def database() -> None:
    """Apply schema + seed once per session, or skip the suite."""
    if not _database_available():
        pytest.skip(
            f"No PostgreSQL at {TEST_DATABASE_URL}. "
            "Start one with `docker compose up -d db` and create the test database.",
            allow_module_level=True,
        )

    from app.seed import apply_schema, apply_seed

    async def setup() -> None:
        await apply_schema()
        await apply_seed()

    asyncio.run(setup())


@pytest.fixture
def client():
    """TestClient with the application lifespan running."""
    from fastapi.testclient import TestClient

    from app.main import app
    from app.services import read_cache

    read_cache.clear()
    with TestClient(app) as c:
        yield c
        read_cache.clear()
