# SukaSeafood

Production monorepo for the SukaSeafood mobile product — point-of-purchase decision support for sustainable Malaysian seafood.

```
Search / Identify → Confirm → Sustainability → Price & Supply → Cooking → Choose
```

## Repository structure

```
sukaseafood/
├── frontend/                 # Flutter mobile app (iOS + Android)
├── backend/                  # FastAPI service + domain data layer
├── data/                     # Raw / reference datasets (not runtime secrets)
│   └── open_dosm/            # OpenDOSM PriceCatcher extracts
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
| [`backend/`](./backend) | FastAPI + SQLAlchemy | Canonical seafood API |
| [`data/`](./data) | CSV / reference | Offline OpenDOSM extracts |
| [`docs/`](./docs) | Markdown + PDFs | Architecture & artefacts |

## Quick start

### 1. Backend

```powershell
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

OpenAPI: http://127.0.0.1:8000/docs

### 2. Frontend

```powershell
cd frontend
flutter pub get
flutter emulators --launch Pixel_8_API_36
flutter run
```

Android emulator → host API: `http://10.0.2.2:8000/api/v1`  
(override with `--dart-define=API_BASE_URL=...`)

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
