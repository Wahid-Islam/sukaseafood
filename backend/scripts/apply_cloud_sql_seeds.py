#!/usr/bin/env python3
"""Apply WWF context and observed-price seeds to production Cloud SQL.

    cd backend && python scripts/apply_cloud_sql_seeds.py

Uses the signed-in gcloud account (mdwahidislamarefin@gmail.com) as a Cloud
SQL IAM user. The access token is never printed.
"""

from __future__ import annotations

import asyncio
import subprocess
import sys
from pathlib import Path

from google.cloud.sql.connector import Connector, IPTypes
from google.oauth2.credentials import Credentials
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

SEED_DIR = Path(__file__).resolve().parents[1] / "db" / "seed"
INSTANCE = "sukaseafood-654b7:us-east4:sukaseafood-654b7-instance"
DB_USER = "mdwahidislamarefin@gmail.com"
DB_NAME = "sukaseafood-654b7-database"
FILES = ("11_wwf_sos_2022.sql", "12_observed_prices.sql")


def _access_token() -> str:
    gcloud = Path(
        r"C:\Users\Wahid\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
    )
    return subprocess.check_output(
        [str(gcloud), "auth", "print-access-token"],
        text=True,
        shell=False,
    ).strip()


async def _execute_file(engine, path: Path) -> None:
    sql = path.read_text(encoding="utf-8")
    async with engine.begin() as conn:
        raw = await conn.get_raw_connection()
        await raw.driver_connection.execute(sql)


async def main() -> int:
    missing = [name for name in FILES if not (SEED_DIR / name).is_file()]
    if missing:
        print("missing seed files:", ", ".join(missing), file=sys.stderr)
        return 1

    creds = Credentials(token=_access_token())
    loop = asyncio.get_running_loop()
    connector = Connector(loop=loop, credentials=creds)

    async def getconn():
        return await connector.connect_async(
            INSTANCE,
            "asyncpg",
            user=DB_USER,
            db=DB_NAME,
            enable_iam_auth=True,
            ip_type=IPTypes.PUBLIC,
        )

    engine = create_async_engine(
        "postgresql+asyncpg://",
        async_creator=getconn,
        poolclass=NullPool,
    )
    try:
        for name in FILES:
            path = SEED_DIR / name
            print(f"applying {name}", flush=True)
            await _execute_file(engine, path)
            print(f"ok {name}", flush=True)
    finally:
        await engine.dispose()
        await connector.close_async()
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
