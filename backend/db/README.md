# Database

PostgreSQL 14+ is the **system of record** for SukaSeafood. Everything the app
displays — species, aliases, WWF ratings, prices, cooking guidance and the
provenance behind each — lives here. Firebase stores images and serves the web
build; it holds no domain data.

## Layout

```
backend/db/
├── schema/
│   ├── i1_initial_schema.sql      17 tables + 8 enums (the reviewed handoff DDL)
│   └── i1_functions_indexes.sql   suka_uuid5(), natural keys, read-path indexes
├── seed/
│   ├── 01_locations.sql           16 states + 178 districts
│   ├── 02_data_sources.sql        publishers + dated source snapshots
│   ├── 03_cooking_methods.sql     cooking vocabulary
│   └── 04_seafood_i1.sql          5 species, aliases, WWF ratings, cooking
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
alembic upgrade head              # schema only
python -c "import asyncio; from app.seed import apply_seed; asyncio.run(apply_seed())"
```

## Design decisions worth knowing

**Deterministic primary keys.** Reference rows use `suka_uuid5('seafood_item:SF001')`
rather than `gen_random_uuid()`, so every environment — local, CI, Supabase —
produces the same ids. `price_summary` and `price_trend_point` reference
`location_id`, so stable keys let price rollups be rebuilt or moved between
environments without remapping. The function is byte-compatible with Python's
`uuid.uuid5`, which lets SQL seeds and Python ETL agree on keys with no
coordination.

**No UNDETERMINED rating.** `sustainability_rating_enum` is
`BEST_CHOICE | REDUCE | AVOID`. A species we cannot rate has **no
`wwf_assessment` row**, and the API surfaces that as UNDETERMINED. Kerapu Bintik
(SF005) is seeded this way on purpose. Making UNDETERMINED a rating value would
erase the difference between "assessed and unclear" and "never assessed".

**Snapshots, not overwrites.** Every fact table points at a `source_snapshot` —
one dated extract from one publisher. Importing newer data adds rows; it never
mutates the evidence behind a number a user has already been shown.

**Quality gates on price.** `price_summary` carries `observation_count`,
`premise_count` and `distinct_day_count`, and `quality_status` is derived from
them. Anything not `DISPLAYABLE` must be shown as "insufficient data" — a median
of three observations from one shop is worse than no number.

**Case-insensitive aliases.** Uniqueness and search both run on
`LOWER(TRIM(alias_name))`. Two aliases for the same species differing only in
case are the same alias.

## Tables

| # | Table | Holds |
|---|---|---|
| 1 | `location` | States and districts; districts parent to their state |
| 2 | `seafood_item` | Canonical species — the hub of the domain |
| 3 | `seafood_alias` | Every spelling search must resolve |
| 4 | `data_source` | Publishers (WWF, OpenDOSM, team, CV model) |
| 5 | `source_snapshot` | One dated extract from a publisher |
| 6 | `wwf_assessment` | Sustainability ratings, with raw source wording |
| 7 | `pricecatcher_item` | Items as OpenDOSM defines them |
| 8 | `price_item_mapping` | Species → PriceCatcher item, with priority |
| 9 | `price_summary` | 30/90-day median rollups + quality gate |
| 10 | `price_trend_point` | Weekly medians for the 12-week chart |
| 11 | `supply_landing_point` | Monthly landings; no species dimension by design |
| 12 | `cooking_method` | Cooking vocabulary |
| 13 | `cooking_suitability` | Species × method score 1–5 with a reason |
| 14 | `cv_model_version` | Deployed CV models + their thresholds |
| 15 | `recipe` | Imported recipes (JSONB ingredients/instructions) |
| 16 | `recipe_seafood_mapping` | Recipe → species |
| 17 | `recipe_cooking_method` | Recipe → cooking method |

Tables 7–11, 14–17 are **empty until the ETL runs**. That is expected, not a
failure: `verify.sql` says so explicitly.
