# Database

PostgreSQL 14+ is the **system of record** for SukaSeafood. Everything the app
displays — species, aliases, WWF ratings, prices, cooking guidance and the
provenance behind each — lives here. Firebase Hosting/Storage deliver the web
build and images; Firebase SQL Connect points at the same Cloud SQL instance
that holds this schema.

## Layout

```
backend/db/
├── schema/
│   ├── v3_initial_schema.sql      21 domain tables + 11 enums (V3 contract)
│   ├── v3_migrate_from_i1.sql     upgrades an existing I1 database to V3
│   ├── v3_functions_indexes.sql   suka_uuid5() + operational indexes
│   └── i1_app_user.sql            app accounts (PostgreSQL only)
├── seed/
│   ├── 01_locations.sql           16 states + 178 districts
│   ├── 02_data_sources.sql        publishers + dated source snapshots
│   ├── 03_cooking_methods.sql     cooking vocabulary
│   └── 04_seafood_i1.sql          5 species + aliases + WWF + cooking
├── docker-initdb/                 runs automatically on a fresh Docker volume
├── apply.sh                       apply everything to any database
└── verify.sql                     post-apply checks
```

Every file is **idempotent**. Re-running is the normal way to pick up new
reference rows.

## Getting a database

```bash
# from the repo root
docker compose up -d db          # Postgres 16 on localhost:5432, schema + seed applied
docker compose logs -f db        # watch the init run
```

The container applies `schema/` then `seed/` on first start. To reset:

```bash
docker compose down -v && docker compose up -d db
```

## Applying to an existing database

```bash
cd backend/db
DATABASE_URL=postgresql://user:pass@host:5432/dbname ./apply.sh
./apply.sh --schema-only          # structure without reference data
```

Or from the backend, through Alembic:

```bash
cd backend
alembic upgrade head              # schema only (includes 0003_v3_schema)
python -c "import asyncio; from app.seed import apply_seed; asyncio.run(apply_seed())"
```

## V3 design decisions

**Canonical hub.** `seafood_item_id` is the only application-wide seafood ID.
PriceCatcher item codes, WWF source rows, premise codes and CV labels are never
canonical.

**Derived price layer.** `price_period_summary` and `price_trend_point` are keyed
by `seafood_item_id` so a fish page can aggregate multiple legitimate
PriceCatcher variants. Observed prices stay separate from `price_forecast`.

**WWF is one-to-many.** One fish can have multiple assessments (catch method /
origin context). The product must not collapse them into a single arbitrary
rating.

**Feature availability is derived.** A master seafood may have WWF but no
PriceCatcher mapping (or vice versa). Missing data is an explicit product state.

**Deterministic primary keys.** Reference rows use `suka_uuid5(...)` so every
environment produces the same ids.

**No UNDETERMINED rating.** `sustainability_rating_enum` is
`BEST_CHOICE | REDUCE | AVOID`. Unrated species have no `wwf_assessment` row.

**Snapshots, not overwrites.** Fact tables point at a `source_snapshot`. Soft
delete uses `active = FALSE` where applicable. Timestamps are UTC.

## Tables

| # | Table | Holds |
|---|---|---|
| 1 | `location` | States and districts |
| 2 | `seafood_item` | Canonical seafood hub |
| 3 | `seafood_alias` | Search vocabulary |
| 4 | `data_source` | Publishers |
| 5 | `source_snapshot` | Dated extracts |
| 6 | `wwf_assessment` | Context-dependent sustainability |
| 7 | `pricecatcher_item` | Official PriceCatcher items |
| 8 | `pricecatcher_premise` | Official premises + retail class |
| 9 | `price_item_mapping` | Canonical ↔ PriceCatcher bridge |
| 10 | `price_period_summary` | Week/month/quarter rollups by seafood |
| 11 | `price_trend_point` | Weekly medians by seafood |
| 12 | `forecast_model_version` | ETS model identity + metrics |
| 13 | `price_forecast` | Expected range + outlook |
| 14 | `supply_landing_point` | Landings (no species dimension) |
| 15 | `cooking_method` | Cooking vocabulary |
| 16 | `cooking_suitability` | Species × method score |
| 17 | `cv_model_version` | Deployed CV models |
| 18 | `cv_class_mapping` | Model label → seafood_item_id |
| 19 | `recipe` | Imported recipes |
| 20 | `recipe_seafood_mapping` | Recipe → species |
| 21 | `recipe_cooking_method` | Recipe → cooking method |

Plus `app_user` for mobile accounts.

Price/forecast/CV/recipe ETL tables are **empty until the pipeline runs**.
`verify.sql` says so explicitly.
