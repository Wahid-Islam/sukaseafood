# SukaSeafood

Production monorepo for the SukaSeafood mobile product — point-of-purchase decision support for sustainable Malaysian seafood.

```
Search / Identify → Confirm → Sustainability → Price → Cooking → Choose
```

## Repository structure

```
sukaseafood/
├── frontend/                 # Flutter mobile app (iOS + Android)
├── backend/                  # FastAPI service + domain data layer
├── data/                     # Raw / reference datasets (not runtime secrets)
│   └── open_dosm/            # OpenDOSM PriceCatcher extracts
├── docker-compose.yml        # Local PostgreSQL
├── firebase.json             # Firebase Hosting (web build + /api rewrite)
├── docs/                     # Product & engineering documentation
│   ├── architecture/
│   └── artefacts/            # Discovery / iteration PDFs
└── .github/workflows/        # CI pipelines (frontend + backend)
```

Frontend and backend are **separate deployable packages** with their own README, dependencies, and CI. They communicate only over the versioned HTTP API (`/api/v1`).

## Packages

| Package | Stack | Responsibility |
| --- | --- | --- |
| [`frontend/`](./frontend) | Flutter 3.44 / Dart 3.12 | iOS + Android client |
| [`backend/`](./backend) | FastAPI + SQLAlchemy + PostgreSQL | Canonical seafood API |
| [`data/`](./data) | CSV / reference | Offline OpenDOSM extracts |
| [`docs/`](./docs) | Markdown + PDFs | Architecture & artefacts |

## Quick start

### 1. Database

PostgreSQL is the system of record. The container applies the V3 schema
(canonical `seafood_item` hub) and the reference seed on first start.

```bash
cp .env.example .env          # once — sets the container's port and credentials
docker compose up -d db
```

If port 5432 is already taken (a system Postgres, Postgres.app, another
project), set `POSTGRES_PORT=5433` in that `.env` and match the port in
`backend/.env`'s `DATABASE_URL`. Check what holds it with
`sudo lsof -nP -iTCP:5432 -sTCP:LISTEN`.

Browse the data: `docker compose exec db psql -U sukaseafood -d sukaseafood`,
or `docker compose --profile tools up -d pgadmin` for a web UI on
http://localhost:5050.

Details and design notes: [`backend/db/README.md`](./backend/db/README.md)

### 2. Backend

```bash
cd backend
pip install -r requirements.txt
cp .env.example .env
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

OpenAPI: http://127.0.0.1:8000/docs
Readiness: http://127.0.0.1:8000/api/v1/health/db

### 3. Frontend

```powershell
cd frontend
flutter pub get
flutter emulators --launch Pixel_8_API_36
flutter run
```

Android emulator → host API: `http://10.0.2.2:8000/api/v1`  
(override with `--dart-define=API_BASE_URL=...`)

## Live deployments

| Track | Web | API | Database |
| --- | --- | --- | --- |
| **Iteration 1 freeze** | https://sukaseafood-i1.web.app | `sukaseafood-api-i1` | `sukaseafood-i1-database` |
| **Working (Iteration 2+)** | https://sukaseafood-654b7.web.app | `sukaseafood-api` | `sukaseafood-654b7-database` |

Iteration 2 work goes only to the working row. Do not deploy to Hosting target `i1` or Cloud Run service `sukaseafood-api-i1`.

```bash
cd frontend && flutter build web --release
# from repo root — working site only:
npx -y firebase-tools@latest deploy --only hosting:live --project sukaseafood-654b7
gcloud run deploy sukaseafood-api --source=. --region=asia-southeast1 --project=sukaseafood-654b7
```

## Iteration 1 scope

**Supported species:** Kembung/Pelaling · Bawal Hitam · Ikan Merah · Tilapia · Kerapu Bintik

**In scope:** search, mock CV identify, WWF sustainability, observed price context, cooking suitability, supporting favourites/profile shells.

**Out of scope:** Smart Swap, NLP cooking intent, price forecasting, species-level supply prediction, demand-side simulator, species expansion.

## Data attribution

- [WWF Save Our Seafood](https://www.saveourseafood.my/) — sustainability classifications  
- [OpenDOSM PriceCatcher](https://open.dosm.gov.my/data-catalogue/pricecatcher) — observed prices  
- [Fish-Vista](https://github.com/sajeedmehrab/Fish-Vista) — future CV backbone  
- [OBIS](https://portal.obis.org/data/access/) — future marine biodiversity context ([data policy](https://www.obis.org/data/datapolicy/))

## Licence

Source code: MIT (see [`LICENSE`](./LICENSE)).  
Third-party datasets retain their original licences — verify before redistribution.
