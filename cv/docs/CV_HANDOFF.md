# SukaSeafood — Computer Vision Scanner

## Iteration 1 handoff: what was built, what it scores, and what it cannot do yet

Model version `cv-i1-2026-08-30` · 30 August 2026

---

## 1. Summary

The scanner is built, trained, exported, registered and serving. A photograph
posted to `POST /api/v1/identify` comes back as up to three ranked candidate
species, each already resolved to the canonical `seafood_item_id` that price,
sustainability, cooking and search all key off.

| Measure | Result |
|---|---|
| Top-1 accuracy | **78.0%** (156/200) |
| Top-3 hit rate | **94.0%** (188/200) |
| Species scannable | 9 of the 12 in the catalogue |
| Model size | 6.1 MB ONNX, CPU-only |
| Evaluation | 200 held-out images, served **through the live API** |

That last row matters more than it looks. The figures were not read off the
training checkpoint; every one of the 200 images was posted to the running
server and scored from the HTTP response. They therefore include the ONNX
graph, the preprocessing, the confidence threshold, the class mapping and the
database join. The API result matches the offline evaluation to four decimal
places, which is the evidence that nothing in the serving path drifted.

**Before quoting 78% anywhere, read section 3.**

---

## 2. What a scan actually does

```
photo ──▶ ONNX ──▶ class index 0..8
                        │
                        ▼  class_map.json  (frozen with the artifact)
                   "SF012"
                        │
                        ▼  cv_class_mapping  (the database owns this join)
          seafood_item_id = 1199fcbe-7fdd-5c16-a3a1-911247053b04
                        │
        ┌───────────────┼────────────────┬──────────────┐
        ▼               ▼                ▼              ▼
   seafood_alias  wwf_assessment  cooking_suitability  price_period_summary
```

The model never learns a UUID. It emits a class code, and the database turns
that into a key — the **same** key search returns for a shopper who typed
"tenggiri". A scanned fish and a searched fish are one entity, so everything
already built on top of `seafood_item_id` works from a photograph on day one,
and a better model can be swapped in without any of it changing.

Verified for all nine classes: each id returned by `/identify` resolves through
`GET /seafood/{uuid}`, returns byte-identical JSON to `GET /seafood/{code}`, and
carries populated aliases, cooking suitability, sustainability and price
sections.

### Response contract

`/identify` returns HTTP 200 in two business states:

- **`CANDIDATES`** — top-1 is at or above the 0.50 threshold.
- **`LOW_CONFIDENCE`** — below it. Still 200, still with the full candidate
  list, because a user who needs to disambiguate needs to *see* the options. A
  4xx here would push the client into an error path and throw them away.

`confirmation_required` is always `true`. Top-1 is never presented as settled
fact. 28 of the 200 test images came back `LOW_CONFIDENCE` — the model saying
"not sure" rather than guessing, which is the correct behaviour and not a
failure.

Errors: `415` wrong media type, `413` over 10 MB, `422` undecodable image,
`503` model or class map unavailable. 415 and 413 are decided *before* the
model is touched, so a junk upload cannot spend inference CPU.

**Uploaded photographs are never stored and never become training data.** The
bytes exist as one local variable and are dropped in a `finally`.

---

## 3. The honest caveat

Every training image is a **wild or museum-specimen photograph** — fish in the
sea, on a boat deck, or pinned on a specimen board — sourced from iNaturalist,
GBIF and the Atlas of Living Australia. Not one is a Malaysian wet-market
counter.

A shopper photographs fish lying on ice, under fluorescent light, overlapping
each other, frequently cut into steaks. That is a different visual domain, and
**78% is not a prediction of what a shopper will experience.** Retail
performance is unmeasured and will be lower.

This is a data problem, not an architecture problem. A few hundred photographs
from real markets — `docs/PHOTO_GUIDE.md` specifies how to take them — and a
retrain would produce a number that means something. Nothing else has to change.

Two further limits, stated plainly:

**Labels are unverified.** Species determinations come from the aggregators.
Nobody with ichthyology training has checked them. Some proportion of the
training set is mislabelled, and that ceiling is invisible in the accuracy
figure.

**Two classes are not usable yet.**

| Class | Species | Recall | Test images |
|---|---|---|---|
| SF010 | Pelata (*Alepes melanoptera*) | 40% | 5 |
| SF009 | Kerisi (*Nemipterus japonicus*) | 42% | 12 |

Both are thin and confusable with their neighbours. The threshold routes most
of their predictions to `LOW_CONFIDENCE`, so the app says "not sure" rather
than naming the wrong fish — the failure is contained, but they need more
images before they are dependable. Five test images is too few to state a
recall for SF010 with any confidence at all.

### Per-class results, weakest first

| Class | Species | Top-1 | Top-3 | n |
|---|---|---|---|---|
| SF010 | Pelata | 0.40 | 1.00 | 5 |
| SF009 | Kerisi | 0.42 | 0.83 | 12 |
| SF007 | Cencaru | 0.62 | 0.84 | 32 |
| SF011 | Selar Kuning | 0.70 | 1.00 | 23 |
| SF008 | Jenahak | 0.83 | 0.92 | 24 |
| SF012 | Tenggiri | 0.87 | 0.97 | 38 |
| SF006 | Bawal Putih | 0.88 | 1.00 | 8 |
| SF002 | Bawal Hitam | 0.90 | 1.00 | 20 |
| SF001 | Kembung / Pelaling | 0.92 | 0.95 | 38 |

Most common confusion: Cencaru called Kembung (7 times). Both are streamlined
silver pelagics of similar size photographed at similar angles; the distinction
is the hardtail scad's scutes along the tail, which a 224-pixel crop of a fish
in open water often does not resolve.

---

## 4. Why nine species and not twelve

`SF003` Ikan Merah, `SF004` Tilapia and `SF005` Kerapu Bintik carry
`supports_cv = FALSE`. No public dataset has usable imagery for them.

The catalogue was deliberately **not** trimmed to match the model. Those three
have working search, WWF ratings and cooking data that the app already ships;
deleting working features to make two numbers line up would be a poor trade. The
database enforces the distinction in both directions, so the catalogue and the
class map cannot silently drift apart:

- exactly one active `cv_model_version`
- one mapping per class the model emits, indices forming a complete `0..8`
- no mapping to a species flagged `supports_cv = FALSE`
- no species flagged `supports_cv = TRUE` without a mapping to back it up
- no CV-scannable species without cooking data — a scan must not open an empty
  page

Each is a `RAISE EXCEPTION` in the seed. They exist because this class of bug is
silent: the request succeeds, the UUID is real, the profile renders, and the
fish is wrong.

> `SF008` Jenahak is *Lutjanus johnii*; `SF003` Ikan Merah is *Lutjanus sebae*.
> Different species, deliberately separate rows, easily conflated because both
> are red snappers sold under overlapping Malay names.

---

## 5. How it was trained

**Two stages, CPU only.** Stage A fits a linear probe on frozen ImageNet
features to establish a floor cheaply. Stage B unfreezes the last blocks at a
low learning rate. On a laptop CPU the whole run is minutes, not hours — which
matters, because a pipeline nobody can afford to re-run is a pipeline that
stops being used.

**Group-aware splitting.** The corpus carries perceptual hashes, and
visually-identical images (the same photograph re-encoded by two aggregators —
common across GBIF and iNaturalist) are pinned to a shared `original_group_id`
so they cannot land on opposite sides of a split. Without this, a near-duplicate
in both train and test inflates accuracy with no warning.

**Class weighting.** The corpus runs 5 to 38 images per class in the test split.
Weights compensate, but a thin class stays a weak class.

**Export parity is checked on probabilities and ranking, not raw logits.** A
trained network's logits span tens of units — this one reaches −59 — so an
absolute logit tolerance measures nothing useful. What the backend serves is a
softmax and a Top-3 ordering, so that is what has to survive the export. Worst
observed probability delta across eight random inputs: 2.2 × 10⁻⁵.

---

## 6. Reproducing and retraining

```bash
cd cv
python scripts/import_candidates.py --candidates <corpus>/candidates.csv \
    --images-root <corpus>/images --out data/manifest.csv
python scripts/split_manifest.py --manifest data/manifest.csv --out data/manifest.csv
python scripts/train.py --stage a --manifest data/manifest.csv --root data/images
python scripts/train.py --stage b --manifest data/manifest.csv --root data/images \
    --init-from artifacts/model_stage_a.pt --epochs 15
python scripts/evaluate.py --checkpoint artifacts/model_stage_b.pt \
    --manifest data/manifest.csv --root data/images --splits val test_clean \
    --out artifacts/validation_report.json
python scripts/export_onnx.py --checkpoint artifacts/model_stage_b.pt \
    --version cv-i1-YYYY-MM-DD --validation artifacts/validation_report.json \
    --out handoff/
python scripts/register_model.py        # regenerates the registration SQL
cp -r handoff ../backend/cv_package
```

`register_model.py` is not optional and the SQL it writes is not hand-editable.
The class order is frozen inside `model.onnx`; a hand-typed index produces a
scanner that confidently names the wrong fish with no error anywhere.
`register_model.py --check` fails CI if the artifact and the SQL drift apart.

---

## 7. Test coverage

36 tests against real PostgreSQL — no SQLite substitute, because the schema
depends on enums, JSONB and expression indexes that a substitute would not
enforce.

The scanner tests use **real held-out photographs**, not synthetic noise. A test
that feeds random pixels proves the plumbing works and would keep passing after
a training run that destroyed accuracy. These assert that a photograph of a
kembung comes back as kembung, carrying the same `seafood_item_id` that search
returns for kembung.

Covered: the full error matrix (415/413/422/503); candidate ranking and
ordering; `image_persisted` false and `confirmation_required` true; that no
unscannable species can ever be returned; that `LOW_CONFIDENCE` stays a 200;
that a scanned id and a searched code return identical rows; that every
scannable species has populated aliases, cooking and price sections; that the
seven unrated species report `UNDETERMINED` rather than a guessed rating; and a
regression floor on accuracy set well below the measured figures, high enough to
catch a broken export, a shuffled class map or a wrong preprocessing constant —
each of which collapses accuracy to roughly 1/9.

Tests needing the image corpus skip cleanly when `CV_TEST_IMAGES` is unset, so
CI without the 2 GB image set stays green.

---

## 8. What is deliberately still missing

**WWF ratings for the seven new species.** They report `UNDETERMINED` and will
until someone transcribes the Save Our Seafood guide for them. This is the
correct behaviour, not a gap to paper over: a default rating reads to a shopper
as approval, and inventing one would be the worst thing this application could
do. Absent guidance stays visibly absent.

**Market photographs.** The single highest-value next task, and the one that
turns 78% into a number worth quoting.

**Verified labels.** An ichthyologist, or anyone with reliable field
experience, checking a sample of the training set would establish where the real
ceiling sits.

---

## 9. Files

| Path | What it is |
|---|---|
| `cv/handoff/` | The frozen artifact: `model.onnx`, `class_map.json`, `model_card.json`, `preprocessing.json` |
| `cv/sukacv/` | `classes.py` (frozen class order), `adapter.py` (serving), `export.py` (ONNX + parity) |
| `cv/scripts/` | `import_candidates.py`, `split_manifest.py`, `train.py`, `evaluate.py`, `export_onnx.py`, `register_model.py` |
| `backend/db/seed/05_seafood_cv_expansion.sql` | SF006–SF012 + aliases; flags SF003/4/5 unscannable |
| `backend/db/seed/06_cv_model_registration.sql` | **Generated.** Model version + class map + guard rails |
| `backend/db/seed/07_cooking_cv_expansion.sql` | Cooking suitability for the seven new species |
| `backend/app/services/cv.py` | Adapter lifecycle + `class_code` → `seafood_item_id` resolution |
| `backend/app/api/routes.py` | The `/identify` route and its error matrix |
| `backend/tests/test_api.py` | The 36 tests described above |
