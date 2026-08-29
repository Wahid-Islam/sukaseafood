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
| GET | `/cooking/{method}` | Cooking recommendations |
| POST | `/identify` | CV identify (mock in I1) |
| GET | `/sources` | Traceable source metadata |

`fish_id` is `seafood_item.code` — `SF001`…`SF005`. The surrogate UUID stays
internal so it can change without breaking clients.

## Migrations

```bash
alembic upgrade head                          # apply
alembic downgrade base                        # drop everything (destructive)
alembic revision --autogenerate -m "message"  # new revision from ORM changes
```

Revision `0001` executes `db/schema/*.sql` directly rather than rebuilding the
schema in Python — that SQL is the reviewed artifact and the one applied to
Supabase, so it stays the single definition. Later revisions use normal
`op.*` operations.

## Environment

| Variable | Default | Notes |
| --- | --- | --- |
| `DATABASE_URL` | `postgresql+asyncpg://sukaseafood:sukaseafood@localhost:5432/sukaseafood` | PostgreSQL only |
| `DB_USE_NULL_POOL` | `false` | Set true behind PgBouncer / Supabase transaction pooler |
| `CORS_ORIGINS` | `["*"]` | Tighten in production |
| `FIREBASE_STORAGE_BUCKET` | — | Enables species image URLs |
| `FIREBASE_CREDENTIALS_PATH` | — | Only for signed URLs / uploads |
| `IDENTIFY_MODEL_VERSION` | `mock-cv-v0.1` | Reported by `/identify` |

See `.env.example`, including the Supabase connection-string form.

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
member.
