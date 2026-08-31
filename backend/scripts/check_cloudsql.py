"""Post-apply sanity check against the live Cloud SQL database.

Two things worth failing loudly on:

1. suka_uuid5() parity with Python's uuid.uuid5. Every reference row's primary
   key is derived from it, so if the SQL and Python implementations ever
   disagree the seed silently forks into two parallel sets of species and
   nothing joins any more. Cloud SQL forces the uuid-ossp implementation while
   a plain container uses pgcrypto, which is exactly the situation where a
   divergence would go unnoticed.

2. Row counts for the tables the app reads on its first screen, so a partially
   applied seed is visible before the phone shows an empty list.

Usage (with the Cloud SQL Auth Proxy already listening):
    python scripts/check_cloudsql.py
"""

from __future__ import annotations

import asyncio
import pathlib
import sys
import uuid

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sqlalchemy import text

from app.database import engine

NAMESPACE = uuid.UUID("6f9619ff-8b86-d011-b42d-00c04fc964ff")

PROBE_NAMES = [
    "seafood_item:SF001",
    "seafood_item:SF013",
    "location:STATE:Selangor",
    "data_source:suka_forecast_engine",
]

COUNTED_TABLES = [
    "seafood_item",
    "location",
    "data_source",
    "price_forecast",
    "forecast_model_version",
    "cv_model_version",
    "cv_class_mapping",
    "cooking_method",
    "app_user",
]


async def main() -> int:
    ok = True
    async with engine.connect() as conn:
        for name in PROBE_NAMES:
            in_db = await conn.scalar(text("SELECT suka_uuid5(:n)"), {"n": name})
            in_python = uuid.uuid5(NAMESPACE, name)
            matches = str(in_db) == str(in_python)
            ok = ok and matches
            print(f"{'MATCH ' if matches else 'DIFFER'} {name:34} {in_db}")

        print()
        for table in COUNTED_TABLES:
            count = await conn.scalar(text(f"SELECT count(*) FROM {table}"))
            print(f"{table:26} {count}")

        print()
        rows = await conn.execute(
            text(
                """
                SELECT si.code, si.display_name_en, count(pf.*) AS weeks
                FROM seafood_item si
                JOIN price_forecast pf ON pf.seafood_item_id = si.seafood_item_id
                GROUP BY si.code, si.display_name_en
                ORDER BY si.code
                """
            )
        )
        for code, name, weeks in rows:
            print(f"forecast {code} {name:28} {weeks} weeks")

    print()
    print("uuid5 parity:", "OK" if ok else "BROKEN")
    await engine.dispose()
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
