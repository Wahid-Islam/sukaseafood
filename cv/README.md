# cv — SukaSeafood scanner model

Nine-class whole-fish classifier, the training pipeline that produced it, and
the ONNX adapter the backend serves. Implements `08 — CV Integration Contract`.

**Status: trained, exported, registered and serving.** `cv-i1-2026-08-30` scores
**78% top-1 / 94% top-3** on 200 held-out images, measured through the live API
rather than against the checkpoint. Read the caveat below before quoting either
number.

| | |
|---|---|
| Model version | `cv-i1-2026-08-30` |
| Backbone | `mobilenetv3_small_100`, ImageNet init, 224 px, CPU-only |
| Classes | 9 (`SF001`, `SF002`, `SF006`–`SF012`) |
| Training images | 932 train / 202 val / 200 test, group-aware split |
| Confidence threshold | 0.50 |
| Artifact | `handoff/model.onnx`, 6.1 MB, opset 17 |

## The caveat that travels with the numbers

Every training image is a **wild or museum-specimen photograph** from
iNaturalist, GBIF and the Atlas of Living Australia: fish in the sea, on a boat,
or pinned on a specimen board. Not one is a Malaysian wet-market counter.

A shopper photographs fish on ice, under fluorescent light, overlapping, often
cut. That is a different visual domain, and **78% is not a prediction of what
they will see** — retail performance is unmeasured and will be lower. Fixing
this does not need a better architecture; it needs a few hundred photographs
from actual markets (`docs/PHOTO_GUIDE.md` says how to take them). Retrain with
those and the figure becomes meaningful.

Two further limits worth stating plainly:

- **Labels are unverified.** They come from the aggregators' own species
  determination. Nobody with ichthyology training has checked them.
- **Two classes are weak.** `SF010` Pelata (40% recall, 5 test images) and
  `SF009` Kerisi (42%) are thin and confusable with their neighbours. The
  threshold routes most of those to `LOW_CONFIDENCE`, so the app says "not
  sure" rather than naming the wrong fish — but they are not usable yet.

## Which fish, and why not the other three

Nine of the twelve catalogue species are scannable. `SF003` Ikan Merah, `SF004`
Tilapia and `SF005` Kerapu Bintik are **not**, and carry `supports_cv = FALSE`.

No public dataset has usable market imagery for them, and the catalogue was
deliberately not trimmed to match the model: those three still have working
search, WWF ratings and cooking data that the app already ships. Removing them
to make the two sets line up would delete working features to tidy a number.
The database enforces the distinction in both directions — a species cannot be
advertised as scannable without a class mapping, and a class cannot map to a
species flagged unscannable.

> `SF008` Jenahak is *Lutjanus johnii*; `SF003` Ikan Merah is *Lutjanus sebae*.
> Different fish, deliberately separate rows. They are easy to conflate because
> both are red snappers sold under overlapping Malay names.

## Install

```bash
python -m venv .venv && source .venv/bin/activate
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
pip install -r requirements-train.txt
python scripts/fetch_weights.py          # ImageNet weights, ~10 MB, once
```

CPU-only is what this package is tuned for. Training needs torch; **serving
needs only `onnxruntime`, `numpy` and `pillow`.**

> `download.pytorch.org` and `huggingface.co` are blocked on this project's
> network, so `fetch_weights.py` pulls from the timm GitHub release assets and
> verifies the sha256 prefix in each filename. If GitHub is blocked too,
> download the file the script names and drop it in `weights/` by hand.

## Prove the environment

```bash
python scripts/smoke_test.py
```

Synthesises images, splits, trains, evaluates, exports ONNX and asserts the
adapter contract — Top-3 ranked and sorted, and the right error for oversized,
corrupt and too-small input. Accuracy from this run is meaningless by
construction; it is checking plumbing.

## Rebuild the model

```bash
# 1. manifest from the image corpus's own candidates.csv (keeps provenance)
python scripts/import_candidates.py \
    --candidates ~/Downloads/sukaseafood-fish-images/candidates.csv \
    --images-root ~/Downloads/sukaseafood-fish-images/images \
    --out data/manifest.csv

# 2. add real market photos — this is the work that decides the outcome
python scripts/ingest_folder.py --incoming incoming --out-dir data/images \
    --manifest data/manifest.csv --source "<market, date>" --attribution "<name>"

# 3. am I ready? exits non-zero with a list of what is still missing
python scripts/check_dataset.py --manifest data/manifest.csv --root data/images

# 4. split, group-aware: near-duplicates cannot straddle train and test
python scripts/split_manifest.py --manifest data/manifest.csv --out data/manifest.csv

# 5. linear probe on frozen features, then fine-tune the last blocks
python scripts/train.py --stage a --manifest data/manifest.csv --root data/images
python scripts/train.py --stage b --manifest data/manifest.csv --root data/images \
    --init-from artifacts/model_stage_a.pt --epochs 15

# 6. held-out evidence + threshold sweep
python scripts/evaluate.py --checkpoint artifacts/model_stage_b.pt \
    --manifest data/manifest.csv --root data/images \
    --splits val test_clean --out artifacts/validation_report.json

# 7. freeze the handoff package (checks ONNX parity before writing)
python scripts/export_onnx.py --checkpoint artifacts/model_stage_b.pt \
    --version cv-i1-YYYY-MM-DD --validation artifacts/validation_report.json \
    --out handoff/

# 8. regenerate the SQL that registers it with the database
python scripts/register_model.py
```

Step 8 is not optional and is not hand-editable. It reads `handoff/class_map.json`
and writes `backend/db/seed/06_cv_model_registration.sql`. The class order is
frozen inside `model.onnx`; a hand-typed index produces a scanner that names the
wrong fish **with no error anywhere** — the join succeeds, the UUID is real, the
profile renders. `scripts/register_model.py --check` fails CI if the two drift.

## Serve it

```bash
cp -r handoff ../backend/cv_package
cd ../backend && uvicorn app.main:app --reload
```

The backend seed loader applies `db/seed/*.sql` in filename order, so
`06_cv_model_registration.sql` lands after the species rows it joins to and a
fresh database comes up with a working scanner. With no package on disk,
`/identify` returns `503 MODEL_UNAVAILABLE` and the rest of the API keeps
working.

## How a scan reaches the rest of the app

This is the part worth understanding, because it is what makes the scanner more
than a demo.

```
photo ──▶ ONNX ──▶ class index 0..8
                        │
                        ▼  class_map.json (frozen with the artifact)
                   "SF012"
                        │
                        ▼  cv_class_mapping  (database owns this join)
          seafood_item_id = 1199fcbe-7fdd-5c16-a3a1-911247053b04
                        │
        ┌───────────────┼────────────────┬──────────────┐
        ▼               ▼                ▼              ▼
   seafood_alias  wwf_assessment  cooking_suitability  price_period_summary
```

The model never learns a UUID. It emits `SF012`, and the database turns that
into the key every other table hangs off — the **same** id that search returns
for someone who typed "tenggiri". Scanned and searched are one entity, which is
why a swap to a better model changes nothing above the class map.

## Rules that are not negotiable

From `08 — CV Integration Contract`, enforced in code and SQL rather than only
documented:

- Class index order is frozen with the artifact. Changing it requires a new
  model version and a regenerated class map.
- The adapter returns `class_code`, never a seafood identifier. Canonical
  mapping belongs to the backend.
- `confirmation_required` is always `true`. Top-1 is never auto-finalised.
- `LOW_CONFIDENCE` is a 200 business state, not an error — the candidate list
  still comes back, because a hesitant user needs to see the options.
- Exactly one active `cv_model_version`, one mapping per emitted class, and no
  mapping to a species flagged `supports_cv = FALSE`. All four are `RAISE
  EXCEPTION` guards in the seed.
- Training refuses to run without ImageNet weights rather than silently falling
  back to random initialisation.
- **User inference images are never persisted and never become training data.**
  The uploaded bytes are one local variable, dropped in a `finally`.
