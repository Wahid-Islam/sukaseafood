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
┌────────────┐     HTTPS/JSON      ┌─────────────────┐
│  Flutter   │ ─────────────────── │  FastAPI /v1    │
│  frontend  │                     │  seafood domain │
└────────────┘                     └────────┬────────┘
                                            │
                                   ┌────────▼────────┐
                                   │ SQLite (dev)    │
                                   │ seed + mappings │
                                   └─────────────────┘
```

Future adapters (non-breaking):

- Real CV model behind `POST /identify` (Fish-Vista)
- Postgres for shared environments
- OBIS / MyBIS for marine context (Iteration 2+)

## Fallback product states

Unavailable / Insufficient / Undetermined are **valid UI outcomes** — never invent WWF scores or prices.
