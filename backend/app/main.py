"""SukaSeafood FastAPI application entrypoint."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth_routes import router as auth_router
from app.api.cooking_routes import router as cooking_router
from app.api.me_routes import router as me_router
from app.api.routes import router
from app.config import get_settings
from app.database import dispose_engine, ping, schema_is_present

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI):
    """Verify the database on startup; never mutate it.

    Deliberately does NOT create tables or seed. Schema changes belong to
    `alembic upgrade head` (or backend/db/apply.sh), run as an explicit
    deployment step. An app that silently creates its own tables will happily
    run against a half-migrated database and hide the problem until it is a
    data problem.
    """
    settings = get_settings()

    if not await ping():
        logger.error(
            "Cannot reach PostgreSQL at the configured DATABASE_URL. "
            "Start it with `docker compose up -d db`."
        )
    elif not await schema_is_present():
        logger.error(
            "Connected to PostgreSQL, but the I1 schema is missing. "
            "Run `alembic upgrade head` or `backend/db/apply.sh`."
        )
    else:
        logger.info("PostgreSQL ready (%s).", settings.environment)

    yield

    await dispose_engine()


def create_app() -> FastAPI:
    """Application factory."""
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(router, prefix=settings.api_prefix)
    app.include_router(auth_router, prefix=settings.api_prefix)
    app.include_router(me_router, prefix=settings.api_prefix)
    app.include_router(cooking_router, prefix=settings.api_prefix)
    return app


app = create_app()
