# Backend — SukaSeafood API

FastAPI service that owns the **canonical seafood domain** for Iteration 1.

## Responsibility

- Canonical species records and search aliases
- Sustainability (WWF Save Our Seafood), including an honest UNDETERMINED state
- Observed price context (OpenDOSM PriceCatcher), gated on data quality
- Cooking suitability recommendations
- Mock `/identify` adapter (Fish-Vista CV plugs in later)

## Stack

- Python 3.11+
- FastAPI + Uvicorn
- **PostgreSQL 14+** via SQLAlchemy 2 (async, asyncpg) — the system of record
- Alembic migrations
- Pydantic v2
- Firebase for hosting and image storage only (`firebase-admin` is an optional extra)

There is no SQLite mode. The I1 schema uses enum types, JSONB, expression
indexes and partial unique indexes; a SQLite fallback would pass tests that
production would fail, so `DATABASE_URL` is validated at startup and rejects
anything that is not PostgreSQL.

## Layout

```
backend/
├── app/
│   ├── api/           # HTTP routers
│   ├── models/        # ORM mirroring the 17-table schema
│   ├── schemas/       # API contracts
│   ├── services/      # Domain logic
│   ├── seed/          # Applies db/seed/*.sql
│   ├── config.py
│   ├── database.py    # Async engine + health probes
│   ├── firebase.py    # Storage URLs (no domain data)
│   └── main.py
├── alembic/           # Migrations
├── db/                # Schema, seed, apply.sh  (see db/README.md)
├── tests/
└── requirements.txt
```

## Run locally

```bash
# 1. Start Postgres (from the repo root) — applies schema + seed automatically
docker compose up -d db

# 2. Backend
cd backend
python -m venv .venv && source .venv/bin/activate     # Windows: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env

# Optional — only for signed Storage URLs or server-side uploads.
# Pulls in cryptography, which needs a Rust toolchain if no wheel matches
# your interpreter. Public image URLs work fine without it.
# pip install -r requirements-firebase.txt

# 3. Bring the schema to head (no-op if Docker already applied it)
alembic upgrade head

# 4. Serve
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

OpenAPI: http://127.0.0.1:8000/docs

Check the wiring: `curl localhost:8000/api/v1/health/db` reports whether Postgres
is reachable, whether the schema is applied, and how Firebase is configured.

## API surface (`/api/v1`)

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Liveness |
| GET | `/health/db` | Readiness — Postgres + schema + Firebase state |
| GET | `/seafood` | List supported species |
| GET | `/search?q=` | Alias / name search |
| GET | `/seafood/{fish_id}` | Full profile |
| GET | `/seafood/{fish_id}/price` | Observed price context |
| GET | `/seafood/{fish_id}/forecast` | Modelled 4-week price outlook (Step 33C) |
| GET | `/cooking/{method}` | Cooking recommendations |
| POST | `/identify` | CV identify (ONNX model, `cv/handoff/`) |
| GET | `/sources` | Traceable source metadata |

`fish_id` accepts either `seafood_item.code` (`SF001`…`SF014`) or the canonical
`seafood_item_id` UUID, which is what `/identify` returns — so a confirmed scan
can query price, forecast and cooking without a second lookup.

### Price forecast

`GET /seafood/{fish_id}/forecast?location_id=&weeks=` serves rows produced by
the R pipeline in `backend/Price Forecast/` and stored by
`db/seed/09_price_forecast.sql`. The endpoint is read-only by design: ranges,
direction, dates and confidence are all decided upstream, so nothing in the API
or the client recomputes them.

Two things the response keeps deliberately separate:

- `outlook` is the **directional** verdict — `LIKELY_INCREASE`,
  `LIKELY_DECREASE` or `NO_STRONG_SIGNAL`. The last one is not `STABLE`: it
  means the evidence did not clear the engine's RM0.25 movement threshold. Nine
  of the twelve forecast fish sit there, and the UI must present that as an
  answer rather than a gap.
- `outlook_label` describes where the forecast **band** sits against the
  reference price, which can differ from the directional read.

`quality_status` is `VALID` or `SPARSE_DATA`. A `SPARSE_DATA` forecast is
displayable but rests on thin recent PriceCatcher coverage, and the client is
expected to say so.

404 `FORECAST_UNAVAILABLE` is a normal state: the engine only covers species
that pass its data-eligibility rules.

## Migrations

```bash
alembic upgrade head                          # apply
alembic downgrade base                        # drop everything (destructive)
alembic revision --autogenerate -m "message"  # new revision from ORM changes
```

Revision `0001` executes `db/schema/*.sql` directly rather than rebuilding the
schema in Python — that SQL is the reviewed artifact and the one applied to
Cloud SQL, so it stays the single definition. Later revisions use normal
`op.*` operations.

## Firebase Cloud SQL

The hosted database is Cloud SQL for PostgreSQL, instance
`sukaseafood-654b7:us-east4:sukaseafood-654b7-instance`, database
`sukaseafood-654b7-database`. It has no authorized networks, so all access goes
through the Cloud SQL Auth Proxy.

IAM database authentication is enabled on the instance, which is the reason
there is no shared database password anywhere in this repo: the proxy exchanges
your own `gcloud` credentials for a short-lived login token and presents that as
the password itself.

```bash
gcloud auth login                     # once, if your session has expired

tools/cloud-sql-proxy.exe --auto-iam-authn \
  --token       "$(gcloud auth print-access-token)" \
  --login-token "$(gcloud sql generate-login-token)" \
  --port 5432 sukaseafood-654b7:us-east4:sukaseafood-654b7-instance
```

Both tokens last about an hour; restart the proxy when it stops accepting
connections. Then set `DATABASE_URL` to the local listener with your IAM email
as the username, percent-encoding the `@` (see `.env.example`).

Cloud SQL withholds `CREATE` on the database from ordinary roles, so
`CREATE EXTENSION pgcrypto` fails there. The schema tolerates this: it installs
whichever of `uuid-ossp` and `pgcrypto` it is allowed to, and `suka_uuid5()` is
defined against whichever is present. Both produce identical UUIDv5 values, and
`scripts/check_cloudsql.py` asserts that parity against Python's `uuid.uuid5`
after any apply — worth running, because a divergence there would silently fork
the reference data into two unjoinable sets of keys.

```bash
python scripts/check_cloudsql.py   # uuid parity + row counts
python scripts/smoke_api.py        # /identify and /forecast, incl. error envelopes
```

## Environment

| Variable | Default | Notes |
| --- | --- | --- |
| `DATABASE_URL` | `postgresql+asyncpg://sukaseafood:sukaseafood@localhost:5432/sukaseafood` | PostgreSQL only |
| `DB_USE_NULL_POOL` | `false` | Set true behind PgBouncer or a managed transaction pooler |
| `CORS_ORIGINS` | `["*"]` | Tighten in production |
| `FIREBASE_STORAGE_BUCKET` | — | Enables species image URLs |
| `FIREBASE_CREDENTIALS_PATH` | — | Only for signed URLs / uploads |
| `IDENTIFY_MODEL_VERSION` | `mock-cv-v0.1` | Reported by `/identify` |

See `.env.example`, including the Cloud SQL connection-string form.

## Tests

Tests run against a **real PostgreSQL database** and skip with an explanatory
message if none is reachable.

```bash
docker compose up -d db
createdb -h localhost -U sukaseafood sukaseafood_test    # once
TEST_DATABASE_URL=postgresql+asyncpg://sukaseafood:sukaseafood@localhost:5432/sukaseafood_test pytest
```

`tests/test_schema.py` asserts structural invariants — all 21 domain tables +
`app_user` and 11 enums exist, the ORM covers every table, `suka_uuid5` matches
Python's `uuid5`, and `sustainability_rating_enum` still has no UNDETERMINED
member. It also guards the forecast contract: the 33B columns are present, the
database rejects a `STABLE` outlook, exactly one model version is active, and
every forecast fish carries the full four-week horizon.

## Regenerating the forecast seed

When a new production forecast run lands in `backend/Price Forecast/`:

```bash
cd backend
python scripts/generate_forecast_seed.py     # rewrites db/seed/09_price_forecast.sql
bash db/apply.sh                             # re-applies; idempotent
```

The generator validates the run before writing anything — bounds, positive
prices, a full four-week horizon per fish, one model version — so a bad export
fails at generation time rather than halfway through a seed apply.
