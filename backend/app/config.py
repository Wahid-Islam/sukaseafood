"""Application settings for the SukaSeafood API."""

from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration loaded from environment variables / .env."""

    # --- Application -------------------------------------------------------
    app_name: str = "SukaSeafood API"
    app_version: str = "0.3.0"
    api_prefix: str = "/api/v1"
    environment: str = "development"
    cors_origins: list[str] = ["*"]
    # Set at Cloud Run deploy so /health names the build QA tested against.
    git_sha: str = ""

    # --- Database ----------------------------------------------------------
    # PostgreSQL is the system of record. There is no SQLite fallback: the I1
    # schema depends on enum types, JSONB, expression indexes and partial unique
    # indexes, so a SQLite "dev mode" would silently diverge from production.
    database_url: str = Field(
        default="postgresql+asyncpg://sukaseafood:sukaseafood@localhost:5432/sukaseafood",
        description="Async SQLAlchemy URL (asyncpg driver).",
    )
    # Cloud Run: the Cloud SQL Python Connector talks to this instance over
    # IAM and does not need DATABASE_URL (and must not use a password).
    instance_connection_name: str = ""
    db_user: str = ""
    db_name: str = ""
    db_pool_size: int = 5
    db_max_overflow: int = 10
    db_pool_recycle_seconds: int = 1800
    db_echo: bool = False

    # Disable connection pooling. Required under pytest: a pooled asyncpg
    # connection is bound to the event loop that created it, and the test suite
    # opens a fresh loop per test, so a reused connection raises
    # "attached to a different loop". Also the correct setting behind an
    # external pooler such as PgBouncer or a managed transaction pooler, which
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

    # --- Auth (PostgreSQL app_user + JWT) ---------------------------------
    jwt_secret: str = Field(
        default="dev-only-change-me-sukaseafood",
        description="HMAC secret for access tokens. Set JWT_SECRET in production.",
    )
    jwt_expire_minutes: int = 60 * 24 * 14  # 14 days

    # --- CV ----------------------------------------------------------------
    # Directory holding the CV owner's handoff package: model.onnx,
    # class_map.json, preprocessing.json, model_card.json. Relative paths are
    # resolved against backend/, so the server behaves the same wherever it is
    # launched from.
    # Points at the model package COMMITTED to the repo, so a fresh clone and CI
    # both find it with no setup. backend/cv_package/ is gitignored, so the old
    # default silently produced 503 MODEL_UNAVAILABLE anywhere that directory
    # had not been copied in by hand — which is every CI run.
    # Relative paths resolve against backend/; override with CV_PACKAGE_DIR.
    cv_package_dir: str = "../cv/sukaseafood_cv_handoff"
    # Overrides the threshold recorded in the package. Left None, the validated
    # value from model_card.json is used; if that is null too, every response is
    # LOW_CONFIDENCE, which is the honest state for a model with no validated
    # cut-off. The threshold lives here rather than in the model so it can be
    # tuned without a redeploy.
    cv_confidence_threshold: float | None = None
    cv_intra_op_threads: int = 2

    # --- IUCN Red List -----------------------------------------------------
    # Official token from api.iucnredlist.org. Empty means we keep the
    # recorded seed category and leave population trend unavailable.
    iucn_api_key: str = ""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @field_validator("iucn_api_key", mode="before")
    @classmethod
    def _strip_iucn_key(cls, v: object) -> object:
        return v.strip() if isinstance(v, str) else v

    @field_validator("database_url")
    @classmethod
    def _require_async_postgres(cls, v: str) -> str:
        """Fail fast on a driver the async engine cannot use."""
        if v.startswith("postgres://"):
            # libpq-style short scheme; SQLAlchemy needs the full scheme.
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
    def uses_cloud_sql_connector(self) -> bool:
        return bool(self.instance_connection_name.strip())

    @property
    def is_production(self) -> bool:
        return self.environment.lower() in {"production", "prod"}


@lru_cache
def get_settings() -> Settings:
    """Return the cached settings instance."""
    return Settings()
