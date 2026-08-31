# Architecture overview

## Style

**Modular monorepo** with clear package boundaries:

- `frontend` — presentation + client state (Flutter)
- `backend` — domain API + persistence (FastAPI)
- `data` — immutable reference extracts
- `docs` — product/engineering artefacts

No shared runtime database between client and server. The mobile app talks to backend exclusively via `/api/v1`.

## Canonical seafood model

All epics resolve to one `fish_id`:

```
Search / CV → fish_id → Sustainability + Price + Cooking
```

This prevents divergent records between camera identification and typed search.

## Iteration 1 components

```
┌────────────┐   HTTPS/JSON   ┌─────────────────┐   asyncpg   ┌──────────────────┐
│  Flutter   │ ────────────── │  FastAPI /v1    │ ─────────── │  PostgreSQL 16   │
│  frontend  │                │  seafood domain │             │  V3 schema       │
└─────┬──────┘                └─────────────────┘             └──────────────────┘
      │                                                        system of record
      │ images
      ▼
┌──────────────────┐
│ Firebase         │
│ Hosting+Storage  │   delivery
│ SQL Connect      │   GraphQL mirror of Cloud SQL (V3)
└──────────────────┘
```

### Why PostgreSQL is the only database

The domain is relational and evidence-bearing. A displayed WWF rating has to be
traceable to a dated source snapshot; a displayed price has to be defensible
against the observation counts it was computed from. That means foreign keys,
enum constraints, expression indexes and transactional imports — so the schema
uses them, and there is no SQLite or document-store fallback that would quietly
accept data the production database would reject.

### Schema V3 (canonical hub)

`seafood_item_id` is the only application-wide seafood ID. PriceCatcher codes,
WWF source rows, premise codes and CV labels resolve through mapping tables.
Derived price outputs (`price_period_summary`, `price_trend_point`) are keyed by
`seafood_item_id`. Forecasts and observed prices are separate tables.

### Why Firebase holds no domain assertions

Firebase Hosting serves the Flutter web build; Storage holds imagery;
SQL Connect exposes the Cloud SQL schema via GraphQL. Domain writes still go
through FastAPI + PostgreSQL. Optional `seafood_item.primary_image_url` can
point at a canonical asset; when null the API falls back to Storage paths
derived from `code` (`SF001` → `seafood/SF001.jpg`).

Future adapters (non-breaking):

- Real CV model behind `POST /identify` (Fish-Vista), versioned in `cv_model_version`
- Firebase Cloud SQL as the hosted Postgres target — same schema, same `apply.sh`
- OBIS / MyBIS for marine context (Iteration 2+)

## Fallback product states

Unavailable / Insufficient / Undetermined are **valid UI outcomes** — never invent WWF scores or prices.

## Honest absence over invented certainty

Three states are valid product outcomes, and the schema is shaped so the backend
cannot fake its way past them:

| State | How the database expresses it |
| --- | --- |
| **Undetermined** sustainability | No `wwf_assessment` row. `sustainability_rating_enum` has no UNDETERMINED member, so an unassessed species can never be stored as if it had been assessed. |
| **Insufficient** price data | `price_period_summary.quality_status` is derived from observation, premise and distinct-day counts. Anything but `DISPLAYABLE` must not be rendered as a number. |
| **Unavailable** supply context | `supply_landing_point` has no species dimension. Landings data is not species-resolved, so attaching it to one fish would invent a fact. |

Never invent WWF scores or prices to fill a gap in the UI.
