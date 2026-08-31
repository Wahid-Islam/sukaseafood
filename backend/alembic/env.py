"""Alembic environment.

Two things worth knowing before editing this file:

1. Migrations run SYNCHRONOUSLY, over psycopg, even though the application uses
   asyncpg. Alembic's own machinery is blocking, and mixing an event loop into
   `alembic upgrade` buys nothing.

2. `target_metadata` is set so `alembic revision --autogenerate` can diff FUTURE
   changes against the ORM. The FIRST revision does not come from autogenerate —
   it executes backend/db/schema/*.sql verbatim, because that SQL is the artifact
   the team reviewed and the one applied to Cloud SQL. Regenerating it from ORM
   metadata would create a second, subtly different definition of the same
   schema.
"""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.config import get_settings
from app.database import Base

# Importing the models package registers all V3 domain tables on Base.metadata.
import app.models  # noqa: F401

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

config.set_main_option("sqlalchemy.url", get_settings().sync_database_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Emit SQL to stdout instead of executing it (`alembic upgrade head --sql`)."""
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations against a live database."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
            # Without this, autogenerate proposes dropping every index and
            # constraint the raw SQL created but the ORM does not name.
            include_schemas=False,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
