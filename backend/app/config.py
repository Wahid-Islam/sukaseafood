"""Application settings for the SukaSeafood API."""

from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration loaded from environment variables / .env."""

    # --- Application -------------------------------------------------------
    app_name: str = "SukaSeafood API"
    app_version: str = "0.2.0"
    api_prefix: str = "/api/v1"
    environment: str = "development"
    cors_origins: list[str] = ["*"]

    # --- Database ----------------------------------------------------------
    # PostgreSQL is the system of record. There is no SQLite fallback: the I1
    # schema depends on enum types, JSONB, expression indexes and partial unique
    # indexes, so a SQLite "dev mode" would silently diverge from production.
    database_url: str = Field(
        default="postgresql+asyncpg://sukaseafood:sukaseafood@localhost:5432/sukaseafood",
        description="Async SQLAlchemy URL (asyncpg driver).",
    )
    db_pool_size: int = 5
    db_max_overflow: int = 10
    db_pool_recycle_seconds: int = 1800
    db_echo: bool = False

    # Disable connection pooling. Required under pytest: a pooled asyncpg
    # connection is bound to the event loop that created it, and the test suite
    # opens a fresh loop per test, so a reused connection raises
    # "attached to a different loop". Also the correct setting behind an
    # external pooler such as PgBouncer or Supabase's transaction pooler, which
    # does its own pooling.
    db_use_null_pool: bool = False

    # --- Firebase ----------------------------------------------------------
    # Firebase never stores domain data. It provides:
    #   * Hosting  — the Flutter web build + a rewrite to the FastAPI backend
    #   * Storage  — seafood and CV reference imagery
    # Image URLs are derived from seafood_item.code, so swapping artwork never
    # requires a database write.
    firebase_project_id: str = ""
    firebase_storage_bucket: str = ""
    firebase_credentials_path: str = ""
    firebase_image_prefix: str = "seafood"
    firebase_enabled: bool = True

    # --- CV ----------------------------------------------------------------
    identify_model_version: str = "mock-cv-v0.1"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @field_validator("database_url")
    @classmethod
    def _require_async_postgres(cls, v: str) -> str:
        """Fail fast on a driver the async engine cannot use."""
        if v.startswith("postgres://"):
            # Heroku/Supabase-style URLs; SQLAlchemy needs the full scheme.
            v = v.replace("postgres://", "postgresql://", 1)
        if v.startswith("postgresql://"):
            v = v.replace("postgresql://", "postgresql+asyncpg://", 1)
        if not v.startswith("postgresql+asyncpg://"):
            raise ValueError(
                "DATABASE_URL must be a PostgreSQL URL. "
                f"Got {v.split('://')[0]!r}. "
                "The I1 schema uses enums, JSONB and expression indexes; "
                "other engines are not supported."
            )
        return v

    @property
    def sync_database_url(self) -> str:
        """Blocking URL for Alembic, which runs migrations synchronously."""
        return self.database_url.replace("postgresql+asyncpg://", "postgresql+psycopg://", 1)

    @property
    def is_production(self) -> bool:
        return self.environment.lower() in {"production", "prod"}


@lru_cache
def get_settings() -> Settings:
    """Return the cached settings instance."""
    return Settings()
