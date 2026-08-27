# Lean architecture (next phase)

Agreed direction for SukaSeafood after the UI prototype:

## Stack

| Layer | Choice | Why |
| --- | --- | --- |
| Mobile | Flutter (`frontend/`) | iOS + Android from one codebase |
| Data / auth / files | **PocketBase** | One binary, SQLite, Dart SDK, free self-host (Fly.io / Oracle free tier) |
| Fish ID model | On-device TFLite **or** Hugging Face Space | Prototype does not need our API for CV |
| Price refresh | GitHub Actions cron → PocketBase | OpenDOSM Parquet/CSV weekly load |
| Optional heavy API | FastAPI + Neon later | Only if price/sustainability logic outgrows PB |

## Current state

- Frontend UI matches `PotentialScreenrendersI1.pdf` using **mock catalog data**.
- No live backend required to demo the journey.
- Scan screen returns mock top-3 predictions (placeholder for TFLite / HF).

## PocketBase collections (planned)

- `seafood` — canonical fish records + aliases
- `sustainability` — WWF classification fields
- `prices` — observed OpenDOSM-derived points
- `cooking_suitability` — method scores
- `users` / auth — PocketBase built-in
- `favourites` — per-user saves

## Hosting path

1. Keep polishing Flutter UI against PDF
2. Add PocketBase beside `frontend/` (`pocketbase/` binary + `pb_data` gitignored)
3. Wire Flutter via `pocketbase` Dart package
4. Add HF Space or TFLite for `/scan`
5. Add Actions workflow to refresh OpenDOSM into PocketBase
