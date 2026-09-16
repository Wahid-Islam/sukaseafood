# How to run SukaSeafood locally (with Epic 4 Smart Swap + AI recipes)

Both `.env` files are already filled in:

- `.env` — local database container (port 5433)
- `backend/.env` — API settings + `OPENAI_API_KEY`

> Never commit or share the `.env` files. After rotating your OpenAI key, replace the
> `OPENAI_API_KEY=` line in `backend/.env` and restart the backend.

## 1. Database (Docker Desktop must be running)

```bash
cd sukaseafood-main
docker compose up -d db
```

## 2. Backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Check it at http://127.0.0.1:8000/docs. Use **POST /smart-swap** with
`{"query": "I want to make fish curry for 4 people", "fish_id": "SF003"}`.

## 3. App (new Terminal window)

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

- iOS simulator: `--dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1`
- Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`

Open a fish → **Smart Swap**, or the recipe card on the cooking screen.

## Not included in the zip

`data/open_dosm/` (~1 GB of raw PriceCatcher extracts). The app doesn't need it
to run, because the prices are already in `backend/db/seed/*.sql`. Copy it over
from your original folder if you need to regenerate the seeds.
