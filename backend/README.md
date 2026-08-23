# Backend — SukaSeafood API

FastAPI service that owns the **canonical seafood domain** for Iteration 1.

## Responsibility

- Canonical `fish_id` records and aliases
- Search resolution
- Sustainability (WWF SOS structured payload)
- Observed price context
- Cooking suitability recommendations
- Mock `/identify` adapter (Fish-Vista CV plugs in later)

## Stack

- Python 3.11+
- FastAPI + Uvicorn
- SQLAlchemy 2 (async) + SQLite (local/dev)
- Pydantic v2

## Layout

```
backend/
├── app/
│   ├── api/           # HTTP routers
│   ├── models/        # ORM
│   ├── schemas/       # API contracts
│   ├── services/      # Domain logic
│   ├── seed/          # I1 seed species
│   ├── config.py
│   ├── database.py
│   └── main.py
├── tests/
├── requirements.txt
└── README.md
```

## Run locally

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## API surface (`/api/v1`)

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/health` | Liveness |
| GET | `/seafood` | List supported species |
| GET | `/search?q=` | Alias / name search |
| GET | `/seafood/{fish_id}` | Full profile |
| GET | `/seafood/{fish_id}/price` | Observed price context |
| GET | `/cooking/{method}` | Cooking recommendations |
| POST | `/identify` | CV identify (mock in I1) |
| GET | `/sources` | Traceable source metadata |

## Environment

| Variable | Default | Notes |
| --- | --- | --- |
| `DATABASE_URL` | `sqlite+aiosqlite:///./sukaseafood.db` | Override for Postgres later |
| `CORS_ORIGINS` | `*` | Tighten in production |

## Tests

```powershell
pip install pytest httpx
pytest
```
