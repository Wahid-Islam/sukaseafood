# Epic 4 — Cooking Intent, Smart Swap & AI Recipes

**Natural language → structured intent → explainable ranking → recipe**

## Install

```bash
OPENAI_API_KEY=sk-...your-new-key... python3 docs/epic4/apply_patches.py .   (from the repo root)
```

This copies the new files, patches the existing ones (safe to run again), and
writes the key to `backend/.env`. Git already ignores that file.

## What was added

| Layer | File | Purpose |
|---|---|---|
| API | `backend/app/api/cooking_routes.py` | `POST /api/v1/smart-swap`, `POST /api/v1/recipes/generate` |
| Service | `services/cooking_intent.py` | Rule-based EN/BM parser: dish, method, servings, fish, budget, kids |
| Service | `services/smart_swap.py` | Hard WWF gate + weighted ranking with reasons |
| Service | `services/recipes.py` | OpenAI recipe generation, validated JSON, 30-min cache |
| Service | `services/openai_client.py` | Small httpx client (JSON mode), no SDK |
| Flutter | `features/seafood/smart_swap_screen.dart` | The 3-step screen from the mockup |
| Flutter | `features/cooking/recipe_screen.dart` | Recipe detail, shopping list, step-by-step cooking mode |
| Flutter | `data/models/cooking_intent.dart` | Models |
| Patched | `main.py`, `config.py`, `schemas`, `.env.example`, `api_client.dart`, `app_router.dart`, `cooking_screen.dart` | Wiring |

Routes: `/seafood/:id/swap` (the fish becomes "Your choice"), `/smart-swap?q=...`
(standalone), and `/recipe`.

## Ranking

The WWF check runs first as a hard filter: a swap must be rated strictly better
than your choice, and an UNDETERMINED fish is never "better". A fish also needs
a curated score of at least 3/5 for the method. Fish that pass are then scored:

| Component | Default weight | Weight if affordable / budget |
|---|---|---|
| Sustainability (WWF) | 40% | 35% |
| Cooking suitability (curated 1–5) | 35% | 30% |
| Price (latest PriceCatcher median vs your choice) | 15% | 25% |
| Food-use attributes (same family/type + versatility) | 10% | 10% |

Every card returns a `score_breakdown`, plus the `reasons` and `caveats` shown in "Why …?".

## Security

- The OpenAI key stays on the backend. Flutter only calls your API.
- Cloud Run: `gcloud run services update sukaseafood-api --update-secrets=OPENAI_API_KEY=openai-api-key:latest`
- Model: set `OPENAI_MODEL` (default `gpt-4o-mini`).

## Test

```bash
cd backend && pytest tests/test_epic4_cooking.py
```

The OpenAI calls in these tests are mocked, so they cost nothing.
