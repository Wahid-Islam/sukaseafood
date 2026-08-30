#!/usr/bin/env bash
# Dataset in, deployed model out.
#
#   ./train.sh ~/Downloads/fish-dataset            train, evaluate, install
#   ./train.sh ~/Downloads/fish-dataset --inspect  report the dataset, change nothing
#   ./train.sh ~/Downloads/fish-dataset --quick    Stage A only (minutes, no fine-tune)
#   ./train.sh ~/Downloads/fish-dataset --keep     do not overwrite backend/cv_package
#
# The dataset is a folder with one subdirectory per fish. Names can be class
# codes (SF001..SF005) or ordinary names — kembung, bawal hitam, ikan merah,
# tilapia, kerapu — in any capitalisation. Splits inside or outside the class
# directories are both understood. Run --inspect first if unsure.
#
# Everything it does: ingest -> split -> readiness report -> Stage A linear
# probe -> Stage B fine-tune -> evaluate -> export -> install into the backend.

set -euo pipefail
cd "$(dirname "$0")"

PY="./.venv/bin/python"
DATASET="${1:-}"
shift || true

INSPECT_ONLY=false
QUICK=false
INSTALL=true
EPOCHS=15
for arg in "$@"; do
    case "$arg" in
        --inspect) INSPECT_ONLY=true ;;
        --quick)   QUICK=true ;;
        --keep)    INSTALL=false ;;
        --epochs=*) EPOCHS="${arg#*=}" ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [[ -z "$DATASET" ]]; then
    echo "usage: ./train.sh <dataset-folder> [--inspect] [--quick] [--keep]" >&2
    echo "" >&2
    echo "The dataset folder holds one subdirectory per fish, e.g." >&2
    echo "    fish-dataset/kembung/*.jpg" >&2
    echo "    fish-dataset/bawal_hitam/*.jpg" >&2
    exit 1
fi

DATASET="${DATASET/#\~/$HOME}"
[[ -d "$DATASET" ]] || { echo "error: $DATASET is not a directory" >&2; exit 1; }

# ------------------------------------------------------------------ environment
if ! "$PY" -c "import torch, timm" >/dev/null 2>&1; then
    echo "==> setting up the training environment (torch is a large one-time download)"
    if [[ ! -x "$PY" ]]; then
        BASE=""
        for c in python3.13 python3.12 python3.11 python3.10 python3; do
            if command -v "$c" >/dev/null 2>&1 && \
               "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null; then
                BASE="$(command -v "$c")"; break
            fi
        done
        [[ -n "$BASE" ]] || { echo "error: no Python 3.10+ found" >&2; exit 1; }
        "$BASE" -m venv --clear .venv
    fi
    "$PY" -m pip install --quiet --upgrade pip
    "$PY" -m pip install -r requirements-train.txt
fi

# -------------------------------------------------------------------- inspect
echo ""
"$PY" scripts/inspect_dataset.py --dataset "$DATASET"
$INSPECT_ONLY && exit 0

# --------------------------------------------------------------------- weights
echo ""
"$PY" scripts/fetch_weights.py

# --------------------------------------------------------------------- ingest
# Start from a clean manifest so re-running is idempotent: the dataset folder
# is the source of truth, not whatever a previous run happened to leave behind.
echo ""
echo "=============================== INGEST ==============================="
rm -f data/manifest.csv
"$PY" scripts/ingest_folder.py \
    --incoming "$DATASET" \
    --out-dir data/images \
    --manifest data/manifest.csv \
    --domain RETAIL \
    --source "$(basename "$DATASET")" \
    --attribution "dataset import"

echo ""
echo "================================ SPLIT ==============================="
"$PY" scripts/split_manifest.py --manifest data/manifest.csv --out data/manifest.csv

# The readiness check is advisory here, not a gate. A small dataset produces a
# weak model, and seeing that happen is more useful than being blocked.
echo ""
echo "============================== READINESS ============================="
"$PY" scripts/check_dataset.py --manifest data/manifest.csv --root data/images || {
    echo ""
    echo "  ^ Below the production floor. Training anyway so you can see where"
    echo "    it stands — treat the numbers as provisional, not as evidence."
}

# ------------------------------------------------------------------- stage A
echo ""
echo "=========================== STAGE A: baseline ========================"
"$PY" scripts/train.py --stage a \
    --manifest data/manifest.csv --root data/images --out artifacts

CHECKPOINT="artifacts/model_stage_a.pt"

# ------------------------------------------------------------------- stage B
if ! $QUICK; then
    echo ""
    echo "======================== STAGE B: fine-tune =========================="
    echo "  ~20 minutes on 2 cores. Skip it with --quick."
    "$PY" scripts/train.py --stage b \
        --manifest data/manifest.csv --root data/images \
        --init-from artifacts/model_stage_a.pt --epochs "$EPOCHS" --out artifacts

    # Keep whichever stage actually validated better. A fine-tune that does not
    # beat the linear probe is not an improvement worth shipping.
    BEST=$("$PY" - <<'PYCODE'
import json, pathlib
a = json.loads(pathlib.Path("artifacts/train_stage_a.json").read_text())["val_accuracy"]
b = json.loads(pathlib.Path("artifacts/train_stage_b.json").read_text())["val_accuracy"]
print("artifacts/model_stage_b.pt" if b >= a else "artifacts/model_stage_a.pt")
print(f"  stage A val {a:.4f} | stage B val {b:.4f}", file=__import__("sys").stderr)
PYCODE
)
    CHECKPOINT="$BEST"
    echo "  keeping $CHECKPOINT"
fi

# ------------------------------------------------------------------- evaluate
echo ""
echo "============================== EVALUATE =============================="
"$PY" scripts/evaluate.py --checkpoint "$CHECKPOINT" \
    --manifest data/manifest.csv --root data/images \
    --splits val test_clean test_dirty \
    --out artifacts/validation_report.json

# --------------------------------------------------------------------- export
VERSION="cv-i1-$("$PY" -c "import datetime;print(datetime.date.today().isoformat())")"
echo ""
echo "=============================== EXPORT ==============================="
"$PY" scripts/export_onnx.py --checkpoint "$CHECKPOINT" \
    --version "$VERSION" \
    --validation artifacts/validation_report.json \
    --out handoff

# -------------------------------------------------------------------- install
if $INSTALL; then
    rm -rf ../backend/cv_package
    cp -r handoff ../backend/cv_package
    echo ""
    echo "installed into backend/cv_package as $VERSION"
fi

# -------------------------------------------------------------------- summary
echo ""
"$PY" scripts/report.py --validation artifacts/validation_report.json --version "$VERSION"

echo ""
if $INSTALL; then
    echo "Next:  cd ../backend && ./run.sh --verify"
else
    echo "Next:  cp -r handoff ../backend/cv_package    (--keep meant it was not installed)"
fi
