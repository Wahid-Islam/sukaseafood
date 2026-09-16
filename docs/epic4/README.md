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

## Screens and flow (v2)

The Smart Swap route now has two views, matching the design PDFs:

1. **Cooking Intent**: the sentence, example chips, optional preferences (people, budget, difficulty, dietary), "What we'll consider", and **Find my better match**.
2. **Finding your better match…**: a progress card with three steps.
   - *Understanding your dish* and *Comparing seafood choices* complete when `POST /smart-swap` returns.
   - *Cooking up recipes* completes when `POST /recipes/generate` has returned **3 recipes** and their photos have been pre-loaded (it gives up waiting after 75 s, and any unfinished photo keeps loading in its card).
3. **Your Smart Swap**: "We understand your request as" (method and serves dropdowns re-rank), the swap cards, **Why <fish>?** (reasons, score bars, other options), and a carousel of 3 recipe photo cards with **View all** / **Show 3 more recipes**.

## Malay, Chinese and Indian recipes

Every batch of 3 recipes has **one Malay, one Chinese and one Indian** dish, all using the requested cooking method (for example goreng kunyit, a ginger-soy steamed dish, and varuval for frying). "Show 3 more" continues the rotation. Each recipe returns `cuisine`, which the cards show as a coloured badge, and the photo prompt uses that cuisine's plating style. All three stay halal-friendly: no pork, lard, alcohol or rice wine. A client can override the rotation with `cuisines: ["Chinese", ...]`.

## Recipe photos

- Each recipe returns `image_url` (`/recipes/images/<id>.jpg?t=<signed token>`). The photo is generated on its **first request** with `gpt-image-1-mini` (medium quality, 1536×1024 JPEG), then cached on disk in `backend/generated/recipe_images/`, which is gitignored.
- The token is HMAC-signed with `JWT_SECRET`, so only URLs this server issued can spend credit.
- **Cost:** about US$0.015 per photo, so about $0.05 per new search (3 photos). Repeat views are free.
- **Settings:** `RECIPE_IMAGES_ENABLED`, `OPENAI_IMAGE_MODEL`, `OPENAI_IMAGE_QUALITY`, `OPENAI_IMAGE_SIZE`, `RECIPE_IMAGE_CACHE_DIR`.
- If a photo fails (or photos are off), the card falls back to the catalogue fish art.
- On Cloud Run the disk cache is per instance. A missing photo is regenerated from its signed URL, so nothing breaks, but it costs again. Move the cache to Firebase Storage if that becomes noticeable.

## Security

- The OpenAI key stays on the backend. Flutter only calls your API.
- Cloud Run: `gcloud run services update sukaseafood-api --update-secrets=OPENAI_API_KEY=openai-api-key:latest`
- Model: set `OPENAI_MODEL` (default `gpt-4o-mini`).

## Test

```bash
cd backend && pytest tests/test_epic4_cooking.py
```

The OpenAI calls in these tests are mocked, so they cost nothing.
