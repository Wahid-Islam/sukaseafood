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

from datetime import datetime, timedelta

from google.auth.credentials import Credentials
from google.cloud.sql.connector import Connector, IPTypes
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

DB_DIR = Path(__file__).resolve().parents[1] / "db"
SEED_DIR = DB_DIR / "seed"
INSTANCE = "sukaseafood-654b7:us-east4:sukaseafood-654b7-instance"
DB_USER = "mdwahidislamarefin@gmail.com"
DB_NAME = "sukaseafood-654b7-database"
FILES = (
    (DB_DIR / "schema" / "v3_biodiversity.sql"),
    (SEED_DIR / "14_tongkol.sql"),
    (SEED_DIR / "15_biodiversity.sql"),
)


def _access_token() -> str:
    gcloud = Path(
        r"C:\Users\Wahid\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"
    )
    return subprocess.check_output(
        [str(gcloud), "auth", "print-access-token"],
        text=True,
        shell=False,
    ).strip()


class _GcloudCredentials(Credentials):
    """User gcloud token that can be re-minted when the connector downscopes."""

    def __init__(self) -> None:
        super().__init__()
        self.refresh(None)

    def refresh(self, request) -> None:  # noqa: ARG002
        self.token = _access_token()
        self.expiry = datetime.utcnow() + timedelta(minutes=45)

    def with_scopes(self, scopes, default_scopes=None):  # noqa: ARG002
        copy = _GcloudCredentials()
        return copy


async def _execute_file(engine, path: Path) -> None:
    sql = path.read_text(encoding="utf-8")
    async with engine.begin() as conn:
        raw = await conn.get_raw_connection()
        await raw.driver_connection.execute(sql)


async def main() -> int:
    missing = [str(path) for path in FILES if not path.is_file()]
    if missing:
        print("missing seed files:", ", ".join(missing), file=sys.stderr)
        return 1

    creds = _GcloudCredentials()
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
        for path in FILES:
            print(f"applying {path.name}", flush=True)
            await _execute_file(engine, path)
            print(f"ok {path.name}", flush=True)
    finally:
        await engine.dispose()
        await connector.close_async()
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
