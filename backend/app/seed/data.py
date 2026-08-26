"""Removed — seed data now lives in SQL.

The hand-written Python dictionaries that used to live here were replaced when
PostgreSQL became the system of record. Reference and canonical data is defined
once, in `backend/db/seed/*.sql`:

    01_locations.sql        Malaysian states and districts
    02_data_sources.sql     publishers and dated source snapshots
    03_cooking_methods.sql  the cooking vocabulary
    04_seafood_i1.sql       the five I1 species, aliases, WWF ratings, cooking

One definition, applied by the shell script, the Docker init hook, the Alembic
migration and the test fixtures alike — instead of Python and SQL drifting apart.

Apply it with `backend/db/apply.sh`, or from Python via
`app.seed.apply_seed()`.

This file is kept only so an old `from app.seed.data import SEED_SEAFOOD` fails
with a clear message instead of a bare ImportError. It can be deleted.
"""

raise ImportError(
    "app.seed.data was removed. Seed data lives in backend/db/seed/*.sql; "
    "use app.seed.apply_seed() or backend/db/apply.sh."
)
