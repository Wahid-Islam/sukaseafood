# Quickstart

Three separate jobs. Do them in this order.

---

## 1. Run the app (15 minutes, no model needed)

The API and the Flutter app work today. With no trained model, `/identify`
returns a clean `503 MODEL_UNAVAILABLE` and everything else — search, WWF,
price, cooking — behaves normally.

### Backend

```bash
cd sukaseafood-main/backend
./run.sh
```

That is it. The script builds a virtualenv if one is missing, installs
requirements when they change, verifies the interpreter it is about to use, and
starts the server — calling the venv's python **by path** so `PATH`, Anaconda
and `conda activate` cannot interfere. Expect:

```
==> python 3.10.x  sqlalchemy 2.0.x
==> /Users/you/.../backend/.venv/bin/python
==> http://localhost:8000/docs
```

Other modes:

```bash
./run.sh --port 9000     # any uvicorn flag passes straight through
./run.sh --test          # run the test suite instead of the server
./run.sh --test-cv       # same, but install the CV deps so all 18 tests run
PYTHON=/opt/homebrew/bin/python3.12 ./run.sh    # pick the base interpreter
```

**Python 3.10+ is required** — the models use PEP 604 unions evaluated at
runtime. macOS ships 3.9 at `/usr/bin/python3`, so the script skips it and
looks for something newer; Anaconda's 3.10 is fine.

<details>
<summary>Doing it by hand instead</summary>

```bash
cd sukaseafood-main/backend
~/anaconda3/bin/python -m venv --clear .venv
./.venv/bin/python -m pip install --upgrade pip
./.venv/bin/python -m pip install -r requirements.txt
./.venv/bin/python -c "import sqlalchemy, sys; print(sqlalchemy.__version__, sys.executable)"
./.venv/bin/python -m uvicorn app.main:app --reload --port 8000
```

Call the venv's python by path rather than relying on `source
.venv/bin/activate`. With Anaconda on `PATH`, bare `python`, `pip` and
`uvicorn` frequently still resolve to Anaconda's copies even with the
virtualenv active, and Anaconda's base ships SQLAlchemy 1.4, which this
project cannot run on.

</details>

Running from VS Code or PyCharm? Set the interpreter to
`<repo>/backend/.venv/bin/python`, or the IDE will keep launching Anaconda's.

### Is it working?

```bash
./run.sh --verify
```

Starts a scratch server on a free port, exercises every endpoint including the
whole CV error matrix, prints PASS/FAIL per check and a one-word verdict, then
cleans up after itself. Exits non-zero if anything is broken, so it also works
in CI.

```
Core API
  [PASS] GET /health
  [PASS] GET /seafood returns the catalogue    12 items
  [PASS] GET /search?q=kembung finds it

Computer vision
  [PASS] POST /identify -> 200
  [PASS] returns exactly 3 candidates
  [PASS] candidates sorted by confidence
  ...
============================================================
WORKING — all 20 checks passed.
```

It reports honestly in both directions: with no model installed it expects and
checks for the 503, and it tells you when the model in place is the untrained
dev one.

Interactive docs: <http://localhost:8000/docs>

### Run the tests

```bash
cd sukaseafood-main/backend
./run.sh --test-cv
```

18 tests covering the whole `08 s.8` error matrix. Slow the first time — it
installs torch and exports an ONNX model once.

`./run.sh --test` is the quick version: it runs without the CV dependencies and
**skips** the 14 identify tests, which is easy to mistake for a clean pass. The
script prints a note when that happens.

### Frontend

```bash
cd sukaseafood-main/frontend
flutter pub get
flutter run
```

The Dart changes from this build have **not been compile-checked** — there was
no Flutter SDK available. Run `flutter analyze` first and expect to fix a small
thing or two.

On an Android emulator the app reaches your machine at `10.0.2.2:8000`, which is
already the default. On iOS simulator or desktop:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

---

## 1b. Test the computer vision

`/identify` returns `503 MODEL_UNAVAILABLE` until a model package exists. That
is correct, but it makes the CV path impossible to click through. One command
builds an **untrained dev package** and starts the server with it:

```bash
cd sukaseafood-main/backend
./run.sh --dev-cv
```

First run installs torch into `cv/.venv` and downloads ~10 MB of ImageNet
weights, so give it a few minutes. After that it is seconds.

Open <http://localhost:8000/docs>, expand `POST /identify`, click **Try it
out**, upload any photo:

```json
{
  "status": "CANDIDATES",
  "model_version": "cv-i1-DEV-UNTRAINED",
  "confirmation_required": true,
  "image_persisted": false,
  "candidates": [
    {"rank": 1, "fish_id": "fish_ikan_merah", "code": "SF003",
     "label": "Ikan Merah", "confidence": 0.2384},
    {"rank": 2, "fish_id": "fish_kembung", "code": "SF001",
     "label": "Kembung / Pelaling", "confidence": 0.2182},
    {"rank": 3, "fish_id": "fish_bawal_hitam", "code": "SF002",
     "label": "Bawal Hitam", "confidence": 0.2127}
  ]
}
```

**The classifier head is untrained, so those near-equal scores are the model
saying it has no idea.** That is the truth, not a bug. Use this to test Top-3
rendering, the confirm and "None of these" flows, error states, the Flutter
screen and latency — never to claim a fish was identified. `model_version` is
stamped `UNTRAINED` in every response and the API logs a warning at startup.

Error matrix, by hand:

```bash
curl -X POST localhost:8000/api/v1/identify -F "file=@fish.jpg;type=image/jpeg"  # 200
curl -X POST localhost:8000/api/v1/identify -F "file=@fish.jpg;type=image/gif"   # 415
curl -X POST localhost:8000/api/v1/identify -F "file=@junk.txt;type=image/jpeg"  # 422
```

`rm -rf backend/cv_package` returns to the 503 state.

---

## 2. Get the images

**Yes, this is required, and it is the only thing standing between you and a
working scanner.** There is no shortcut: no public dataset covers Kembung,
Bawal Hitam, Ikan Merah, Tilapia and Kerapu Bintik as they appear on a
Malaysian wet-market slab.

### First, try the 61 Fish-Vista images

```bash
cd sukaseafood-main/cv
python3 -m venv --clear .venv
source .venv/bin/activate
python -m pip install -r requirements-train.txt

python scripts/build_manifest_from_fishvista.py \
    --fishvista-dir "../../SukaSeafood I1 Developer Handoff/data" \
    --out data/manifest_seed.csv

python scripts/download_images.py --manifest data/manifest_seed.csv \
    --out-dir data/images --manifest-out data/manifest.csv
```

`fishair.org` was blocked from the sandbox this was built in, but that block is
on the sandbox, **not necessarily on your laptop**. Run the command above from
your own terminal and see. If it works you get 61 museum specimen photos — a
useful supplement, nowhere near a dataset.

### Then the real work: market photography

Read `cv/docs/PHOTO_GUIDE.md` properly before the first trip. The short version:

**Targets per species:** 150–300 training photos, plus 30–50 for a *separately
collected* dirty test set. Across all species, 40–60 invalid inputs (fillets,
prawns, chicken, blurry shots) so the "not sure" behaviour can be measured.

**Divide the work.** Five species, five people, one market each — a weekend gets
you most of the way. 200 photos of one species takes about 40 minutes if you
vary things properly.

**Vary everything:** angle (side-on matters most), lighting (fluorescent tube vs
daylight vs chill-counter LED), background (ice, steel, tray, polystyrene), wet
vs dry, single fish vs full tray, hands in frame, different phones. Twenty
photos from one spot teach the model one photo.

**Label carefully.** Market names are not species. "Ikan Merah" covers several
snappers; "Kembung" covers more than one *Rastrelliger*. Ask the vendor, and
when unsure flag it rather than guessing — a wrong label is worse than a missing
image, because it teaches the model to be confidently wrong.

**Ask permission** before photographing a vendor's stock, and record who took
each photo.

### Ingest what you collect

Sort into folders by class code — `incoming/SF001/`, `incoming/SF002/`, etc:

| Code | Species |
|---|---|
| SF001 | Kembung / Pelaling |
| SF002 | Bawal Hitam |
| SF003 | Ikan Merah |
| SF004 | Tilapia |
| SF005 | Kerapu Bintik |

```bash
# a normal training batch
python scripts/ingest_folder.py --incoming incoming --out-dir data/images \
    --manifest data/manifest.csv --domain RETAIL \
    --source "Pasar Borong Selayang 2026-08-30" --attribution "Your Name"

# the held-out test set — different day, different market, ideally different person
python scripts/ingest_folder.py --incoming incoming_dirty --out-dir data/images \
    --manifest data/manifest.csv --domain RETAIL --split test_dirty \
    --source "Pasar Chow Kit 2026-09-06" --attribution "Someone Else"

# invalid inputs
python scripts/ingest_folder.py --incoming incoming_invalid --out-dir data/images \
    --manifest data/manifest.csv --domain INVALID --split test_invalid \
    --source "mixed 2026-09-06" --attribution "Your Name"
```

Duplicates are detected by content hash, so re-running an ingest is safe.

### Know when you're done

```bash
python scripts/check_dataset.py --manifest data/manifest.csv --root data/images
```

Run this after every batch. It prints per-class counts and an explicit list of
what is still short, and exits non-zero until you are ready. When it exits
clean, stop collecting and start training.

---

## 3. Train on your dataset

One command, once the images exist:

```bash
cd sukaseafood-main/cv
./train.sh ~/Downloads/your-fish-dataset
```

It ingests, splits, checks readiness, trains both stages, evaluates, exports the
handoff package, installs it into `backend/cv_package`, and prints a report.
Then `cd ../backend && ./run.sh --verify`.

### Importing a Roboflow / Kaggle dataset

Most public fish datasets are annotated for **object detection** — bounding
boxes, and often several fish of different species in one photo. This project's
model is a whole-image classifier, so those photos cannot be used as-is.

**Download it as COCO JSON.** Then:

```bash
./scripts/import_roboflow.py --export ~/Downloads/fish-market.v1 \
    --out ~/Downloads/fish-prepared
./train.sh ~/Downloads/fish-prepared
```

The importer crops every bounding box into its own single-fish image. That is
the right move for three reasons: each crop has one unambiguous label, it is
the kind of image the model expects, and a photo of six fish becomes six
training images instead of one unusable multi-label one.

It also reports any label in the dataset that is not one of our five, and it
refuses to pretend a missing class is fine:

```
class   label                     images
------------------------------------------
SF001   Kembung / Pelaling            12
...
SF005   Kerapu Bintik                  0   <-- none found

Labels in the dataset that are not one of our five:
  'Sotong'      3 annotations  (ignored)
  'Udang'       3 annotations  (ignored)
```

Pascal VOC works identically. **Multi-Label Classification CSV also works but
is the worst option** — no boxes, so whole images only, and every photo
containing two species has to be dropped as ambiguous. Use it only if COCO is
unavailable.

If the dataset names a fish differently from anything in `ALIASES`
(`cv/sukacv/classes.py`), add the name there and re-run rather than renaming
files.

### What the dataset should look like

One folder per fish. Names can be class codes or ordinary names, any
capitalisation, with decoration:

```
your-fish-dataset/
  kembung/              or SF001/  or  "Ikan Kembung"  or  01_kembung_raw
  bawal hitam/          or SF002/  or  black-pomfret
  ikan merah/           or SF003/  or  red_snapper
  tilapia/              or SF004/  or  "Oreochromis niloticus"
  kerapu/               or SF005/  or  grouper
```

Splits (`train/`, `val/`, `test/`) inside or outside the class folders are both
understood, and images in nested subdirectories are picked up. Anything it
cannot map to one of the five is **listed and skipped**, never guessed at.

### Look before you leap

```bash
./train.sh ~/Downloads/your-fish-dataset --inspect
```

Reads the folder and reports what it found, writing nothing:

```
Layout detected: class-at-top

class   label                 folder                         split  images
--------------------------------------------------------------------------
SF001   Kembung / Pelaling    kembung                            -      40
SF002   Bawal Hitam           Bawal Hitam                        -      40
...
1 folder(s) could not be matched to any of the five:
  prawns_NOT_A_CLASS   (5 images)

Class balance: 40–40 images (1.0x imbalance)
```

### Options

```bash
./train.sh <dataset>              full run: Stage A + Stage B, install
./train.sh <dataset> --inspect    report only, change nothing
./train.sh <dataset> --quick      Stage A only — minutes instead of ~20
./train.sh <dataset> --keep       do not overwrite backend/cv_package
./train.sh <dataset> --epochs=25  longer fine-tune
```

Both stages are trained and **whichever validated better is the one shipped** —
a fine-tune that fails to beat the linear probe is not an improvement.

### The report

Ranked worst-first, because the ranking is a photography to-do list:

```
Per fish, weakest first
                                  recall                         prec     n
  SF010   Pelata                  40.0%  ########............   0.40     5
  SF009   Kerisi                  41.7%  ########............   0.63    12
  SF007   Cencaru                 62.5%  #############.......   0.69    32
  SF001   Kembung / Pelaling      92.1%  ##################..   0.83    38

Most common confusions
    7x  SF007 Cencaru             called  SF001 Kembung / Pelaling
    3x  SF011 Selar Kuning        called  SF001 Kembung / Pelaling

Weak — 2 of 9 fish are below 50% recall.
Overall accuracy of 78% hides this, and so does the 94% top-3.
```

Two things it deliberately refuses to let you fool yourself with. A class the
model never predicts still rides along in the top 3, so a dead class overrides
a good headline number. And it always says **which split** produced the figures
— `val` flatters the model because it steered the training run, and even
`test_clean` is wild imagery rather than a market counter.

The `LOW_CONFIDENCE` threshold comes from a sweep over the results. If nothing
qualifies, it reports none and the API answers `LOW_CONFIDENCE` for everything
rather than shipping a guessed cut-off.

### Retraining later

Re-run the same command with a bigger dataset folder. The manifest is rebuilt
from scratch each time, so the folder is the source of truth and repeat runs
are idempotent.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `WeightsMissingError` | Run `python scripts/fetch_weights.py`. Training refuses to run on random weights on purpose |
| `fetch_weights.py` fails | GitHub is blocked. Download the file it names on any machine, drop it in `cv/weights/` |
| `/identify` → 503 | No `backend/cv_package/`, or the class map does not cover all five codes. The message says which |
| Every result is `LOW_CONFIDENCE` | The package has no validated threshold. Correct behaviour — run `evaluate.py` to produce one |
| `pip install torch` pulls 2.5 GB | You are on Linux and getting the CUDA wheel. See the note in `requirements-train.txt` |
| `check_dataset.py` exits 1 | Working as intended. Read the blocker list |
| `/identify` gives near-equal confidences | You are on the dev package. Expected — the head is untrained |
| `cannot import name 'async_sessionmaker'` | SQLAlchemy 1.4 — Anaconda's Python, not the venv. Use `./.venv/bin/python -m ...` |
| `RuntimeError: SukaSeafood needs SQLAlchemy 2.0+` | Same cause, caught early. The message prints the exact commands |
| Any error naming an `anaconda3` path | Activation did not take. Use `./run.sh`, which never relies on it |
| The error reappears right after a file is edited | Look for `WatchFiles detected changes ... Reloading` above it — that is an OLD server auto-reloading. Stop it: `lsof -ti:8000 \| xargs kill` |
| `port 8000 is already in use` | A previous server is still running. `run.sh` refuses to start a second one and prints the kill command |
| `zsh: permission denied: ./run.sh` | `chmod +x run.sh` once, or use `bash run.sh` |
| `No matching distribution found for onnxruntime` | macOS 12 or earlier caps at onnxruntime 1.16.3. `requirements.txt` allows it — make sure you have the current file |
| `_ARRAY_API not found`, or Python dies with no traceback | onnxruntime below 1.19 segfaults under NumPy 2. The pins prevent it; the adapter also refuses the combination with an explanation |
| `SyntaxError` on `str \| None` | Python 3.9. Rebuild the venv from a 3.10+ interpreter |
