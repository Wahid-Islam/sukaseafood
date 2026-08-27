"""Async SQLAlchemy engine, session factory and health helpers."""

from collections.abc import AsyncGenerator

from sqlalchemy import text
from sqlalchemy.pool import NullPool
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings

settings = get_settings()


class Base(DeclarativeBase):
    """Declarative base for all ORM models."""


def _create_engine() -> AsyncEngine:
    """Build the asyncpg engine.

    pool_pre_ping matters in this deployment: Supabase and most managed
    Postgres services drop idle connections, and without it the first request
    after a quiet period fails with a stale-connection error rather than
    transparently reconnecting.
    """
    if settings.db_use_null_pool:
        # No pooling: every connection is created and closed inside the caller's
        # event loop. See Settings.db_use_null_pool for why this exists.
        return create_async_engine(
            settings.database_url,
            echo=settings.db_echo,
            poolclass=NullPool,
        )

    return create_async_engine(
        settings.database_url,
        echo=settings.db_echo,
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_max_overflow,
        pool_recycle=settings.db_pool_recycle_seconds,
        pool_pre_ping=True,
    )


engine: AsyncEngine = _create_engine()

SessionLocal = async_sessionmaker(
    engine,
    expire_on_commit=False,
    autoflush=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency yielding a request-scoped session."""
    async with SessionLocal() as session:
        yield session


async def ping() -> bool:
    """Return True if the database answers a trivial query."""
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception:  # noqa: BLE001 - health probe must never raise
        return False


async def schema_is_present() -> bool:
    """Return True if the I1 schema has been applied.

    Checked on startup so a fresh container fails loudly with "run the
    migrations" instead of returning empty 200s that look like missing data.
    """
    try:
        async with engine.connect() as conn:
            result = await conn.execute(
                text(
                    "SELECT COUNT(*) FROM information_schema.tables "
                    "WHERE table_schema = 'public' "
                    "AND table_name IN ('seafood_item', 'seafood_alias', 'cooking_method')"
                )
            )
            return (result.scalar_one() or 0) == 3
    except Exception:  # noqa: BLE001
        return False


async def dispose_engine() -> None:
    """Close pooled connections on shutdown."""
    await engine.dispose()
