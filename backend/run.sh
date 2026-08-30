#!/usr/bin/env bash
# Start the SukaSeafood API — database, virtualenv, seed and scanner.
#
# Exists because the usual failure on this project is not a code problem. With
# Anaconda on PATH, bare `python`, `pip` and `uvicorn` resolve to Anaconda's
# copies even after `source .venv/bin/activate`, and Anaconda's base ships
# SQLAlchemy 1.4, which this project cannot run on. This script never relies on
# activation: it calls the venv's interpreter by path, so PATH, conda, and which
# shell tab you are in stop mattering.
#
#   ./run.sh                      start the API on port 8000
#   ./run.sh --port 9000          pass any uvicorn flags straight through
#   ./run.sh --scan photo.jpg     scan one image and print the result — no
#                                 server, no curl. The fastest way to see the
#                                 CV working.
#   ./run.sh --verify             answer "is this working?" end to end: starts
#                                 a scratch server, exercises every endpoint
#                                 including the CV error matrix, PASS/FAIL each
#   ./run.sh --test               run the test suite
#   ./run.sh --test-cv            same, plus the scanner accuracy tests against
#                                 the real image corpus (set CV_TEST_IMAGES)
#   ./run.sh --db                 start Postgres and apply schema + seed, then
#                                 stop. Useful on a fresh clone.
#   ./run.sh --reset-db           destroy the database and rebuild it from
#                                 scratch. Everything is re-seeded.
#
# Set PYTHON=/path/to/python3.11 to build the venv from a specific interpreter.

set -euo pipefail
cd "$(dirname "$0")"

VENV="./.venv"
PY="$VENV/bin/python"
PROJECT_ROOT="$(cd .. && pwd)"

# ---------------------------------------------------------------- interpreter
find_python() {
    if [[ -n "${PYTHON:-}" ]]; then echo "$PYTHON"; return; fi
    # 3.10+ required: the models use PEP 604 unions evaluated at runtime, so
    # macOS's /usr/bin/python3 (3.9) is not a candidate.
    for candidate in python3.13 python3.12 python3.11 python3.10 python3 python; do
        if command -v "$candidate" >/dev/null 2>&1; then
            if "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null; then
                command -v "$candidate"; return
            fi
        fi
    done
    return 1
}

# ------------------------------------------------------------------- bootstrap
# A venv can exist and still be unusable: created but never installed into,
# built from a Python that has since moved, or missing pip. Treat "the venv
# directory exists" as no evidence at all and check that it actually works.
venv_is_healthy() {
    [[ -x "$PY" ]] || return 1
    "$PY" -c 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' 2>/dev/null || return 1
    "$PY" -m pip --version >/dev/null 2>&1 || return 1
    return 0
}

if ! venv_is_healthy; then
    if [[ -e "$VENV" ]]; then
        echo "==> $VENV exists but is not usable (missing pip, wrong version, or"
        echo "    built from a Python that has moved) — rebuilding it"
    fi
    BASE_PYTHON="$(find_python)" || {
        echo "error: no Python 3.10+ found." >&2
        echo "       This project needs 3.10+; macOS ships 3.9 at /usr/bin/python3." >&2
        echo "       Install one, or set PYTHON=/path/to/python3.11 and re-run." >&2
        exit 1
    }
    echo "==> creating $VENV from $BASE_PYTHON ($("$BASE_PYTHON" -V 2>&1))"
    "$BASE_PYTHON" -m venv --clear "$VENV"
    "$PY" -m pip install --quiet --upgrade pip
    rm -f "$VENV/.requirements.sha"
fi

# ---------------------------------------------------------------- requirements
STAMP="$VENV/.requirements.sha"
CURRENT="$(shasum requirements.txt | awk '{print $1}')"

install_requirements() {
    # Upgrade pip first. An old pip does not understand newer wheel platform
    # tags and silently resolves to an ancient version of a package — or reports
    # "no matching distribution" for one that does exist for your platform.
    "$PY" -m pip install --quiet --upgrade pip
    echo "==> installing requirements into $PY"
    if ! "$PY" -m pip install -r requirements.txt; then
        echo "" >&2
        echo "error: dependency install failed." >&2
        echo "       If pip reported no matching distribution for onnxruntime," >&2
        echo "       your macOS is older than 13 and caps out at 1.16.3 —" >&2
        echo "       requirements.txt already allows that, so make sure you are" >&2
        echo "       on the current file (git pull / re-copy)." >&2
        exit 1
    fi
    echo "$CURRENT" > "$STAMP"
}

if [[ ! -f "$STAMP" ]] || [[ "$(cat "$STAMP")" != "$CURRENT" ]]; then
    install_requirements
fi

# --------------------------------------------------------------------- repair
# The stamp says what we installed; this says what is actually importable. They
# can disagree — a half-finished install, or packages removed underneath us —
# so repair once rather than failing with a confusing error at import time.
check_env() {
    "$PY" - <<'PYCODE' 2>/dev/null
import sqlalchemy
major, minor = (int(p) for p in sqlalchemy.__version__.split(".")[:2])
raise SystemExit(0 if (major, minor) >= (2, 0) else 1)
PYCODE
}

if ! check_env; then
    echo "==> the virtualenv is missing packages it should have — reinstalling"
    install_requirements
    if ! check_env; then
        echo "error: even after reinstalling, $PY cannot import SQLAlchemy 2.0+." >&2
        echo "       Try a clean rebuild:  rm -rf .venv && ./run.sh" >&2
        exit 1
    fi
fi

"$PY" - <<'PYCODE'
import sys, sqlalchemy
print(f"==> python {sys.version.split()[0]}  sqlalchemy {sqlalchemy.__version__}")
try:
    import onnxruntime, numpy
    print(f"==> onnxruntime {onnxruntime.__version__}  numpy {numpy.__version__}")
except ImportError:
    print("==> onnxruntime NOT installed — /identify will return 503")
print(f"==> {sys.executable}")
PYCODE

# ---------------------------------------------------------------- model check
# cv_package/ is a deploy-time copy of cv/handoff/ and is not in git — keeping
# the same 6 MB artifact in two tracked places invites them to drift. So install
# it here rather than making a fresh clone fail with a 503 nobody expected.
install_model() {
    if [[ -f cv_package/model.onnx ]]; then return 0; fi
    if [[ -f ../cv/handoff/model.onnx ]]; then
        echo "==> installing the model package (cv/handoff -> backend/cv_package)"
        rm -rf cv_package
        cp -r ../cv/handoff cv_package
        return 0
    fi
    echo ""
    echo "==> WARNING: no model found at backend/cv_package/ or cv/handoff/."
    echo "    /identify will return 503 MODEL_UNAVAILABLE; everything else works."
    echo "    Export one with:  cd ../cv && python scripts/export_onnx.py ..."
    echo ""
}
install_model

# -------------------------------------------------------------------- database
DB_PORT="${POSTGRES_PORT:-5432}"
export DATABASE_URL="${DATABASE_URL:-postgresql+asyncpg://sukaseafood:sukaseafood@localhost:$DB_PORT/sukaseafood}"

db_reachable() {
    "$PY" - <<'PYCODE' >/dev/null 2>&1
import asyncio
from app.database import ping
raise SystemExit(0 if asyncio.run(ping()) else 1)
PYCODE
}

# The daemon, not the CLI. `docker` on PATH says nothing about whether Docker
# Desktop is actually running, and the resulting "Cannot connect to the Docker
# daemon" is easy to read as a broken install rather than a stopped app.
docker_daemon_up() {
    command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

# On macOS the fix is always the same — launch Docker Desktop and wait — so do
# it rather than printing an instruction. Nothing here is destructive: it starts
# an app the project already depends on, and gives up cleanly if it does not
# come up.
start_docker_desktop() {
    [[ "$(uname -s)" == "Darwin" ]] || return 1
    [[ -d "/Applications/Docker.app" ]] || return 1

    echo "==> Docker Desktop is not running — starting it (this takes ~30s)"
    open -a Docker || return 1

    echo -n "    waiting for the Docker daemon"
    for _ in $(seq 1 90); do
        if docker_daemon_up; then echo " — up"; return 0; fi
        echo -n "."; sleep 1
    done
    echo ""
    return 1
}

start_db() {
    if db_reachable; then return 0; fi

    if ! command -v docker >/dev/null 2>&1; then
        echo "error: cannot reach PostgreSQL at $DATABASE_URL, and docker is not" >&2
        echo "       installed to start one." >&2
        echo "" >&2
        echo "       The scanner does not need a database — this still works:" >&2
        echo "           ./run.sh --scan <image>" >&2
        echo "" >&2
        echo "       For the full API, either install Docker Desktop, or point" >&2
        echo "       DATABASE_URL at a Postgres you already run:" >&2
        echo "           DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/sukaseafood ./run.sh" >&2
        exit 1
    fi

    if ! docker_daemon_up && ! start_docker_desktop; then
        echo "" >&2
        echo "error: the Docker daemon is not reachable." >&2
        echo "       Docker is installed, but Docker Desktop is not running — start" >&2
        echo "       it from Applications (or run 'open -a Docker'), wait for the" >&2
        echo "       whale icon to stop animating, then re-run this." >&2
        echo "" >&2
        echo "       Meanwhile the scanner needs no database and still works:" >&2
        echo "           ./run.sh --scan <image>" >&2
        exit 1
    fi

    echo "==> starting PostgreSQL (docker compose up -d db)"
    (cd "$PROJECT_ROOT" && docker compose up -d db) || {
        echo "error: docker compose failed even though the daemon is up." >&2
        echo "       Check the logs:  docker compose logs db" >&2
        exit 1
    }

    # The container reports ready before Postgres finishes its first-boot
    # initialisation, so poll rather than sleeping a guessed interval.
    echo -n "==> waiting for it to accept connections"
    for _ in $(seq 1 60); do
        if db_reachable; then echo " — up"; return 0; fi
        echo -n "."; sleep 1
    done
    echo ""
    echo "error: Postgres did not become reachable within 60s." >&2
    echo "       Check the logs:  docker compose logs db" >&2
    exit 1
}

apply_schema_and_seed() {
    echo "==> applying schema and seed (idempotent)"
    "$PY" - <<'PYCODE'
import asyncio
from app.seed import apply_schema, apply_seed

async def main():
    await apply_schema()
    await apply_seed()

asyncio.run(main())
PYCODE
}

if [[ "${1:-}" == "--reset-db" ]]; then
    shift
    command -v docker >/dev/null 2>&1 || {
        echo "error: --reset-db needs docker." >&2; exit 1; }
    echo "==> destroying the database volume and rebuilding from scratch"
    (cd "$PROJECT_ROOT" && docker compose down -v)
    start_db
    apply_schema_and_seed
    echo "==> done."
    exit 0
fi

if [[ "${1:-}" == "--db" ]]; then
    shift
    start_db
    apply_schema_and_seed
    echo "==> database ready at $DATABASE_URL"
    exit 0
fi

# ---------------------------------------------------------------- scan one file
# The shortest path from "is the CV working?" to an answer. No server, no curl,
# no database — this exercises the ONNX artifact and the frozen class map only,
# which is exactly the right scope when the question is about the model.
if [[ "${1:-}" == "--scan" ]]; then
    shift
    [[ $# -ge 1 ]] || { echo "usage: ./run.sh --scan <image> [more images...]" >&2; exit 1; }
    exec "$PY" scan.py "$@"
fi

# -------------------------------------------------------------------- verify
if [[ "${1:-}" == "--verify" ]]; then
    shift
    start_db
    apply_schema_and_seed
    exec "$PY" verify.py "$@"
fi

# ---------------------------------------------------------------------- tests
if [[ "${1:-}" == "--test" ]]; then
    shift
    "$PY" -m pip install --quiet pytest anyio httpx
    export TEST_DATABASE_URL="${TEST_DATABASE_URL:-postgresql+asyncpg://sukaseafood:sukaseafood@localhost:$DB_PORT/sukaseafood_test}"
    start_db
    # The suite creates its own schema, but not its own database.
    "$PY" - <<'PYCODE' || true
import asyncio, os, asyncpg, urllib.parse as up
url = up.urlparse(os.environ["TEST_DATABASE_URL"].replace("postgresql+asyncpg", "postgresql"))
name = url.path.lstrip("/")
async def main():
    conn = await asyncpg.connect(host=url.hostname, port=url.port,
                                 user=url.username, password=url.password,
                                 database="postgres")
    exists = await conn.fetchval("SELECT 1 FROM pg_database WHERE datname=$1", name)
    if not exists:
        await conn.execute(f'CREATE DATABASE "{name}"')
        print(f"==> created test database {name}")
    await conn.close()
asyncio.run(main())
PYCODE
    if [[ -z "${CV_TEST_IMAGES:-}" ]]; then
        echo "==> note: CV_TEST_IMAGES is not set, so the 2 scanner accuracy"
        echo "    tests will SKIP. To include them:  ./run.sh --test-cv"
    fi
    exec "$PY" -m pytest tests -q "$@"
fi

if [[ "${1:-}" == "--test-cv" ]]; then
    shift
    : "${CV_TEST_IMAGES:=$HOME/Downloads/sukaseafood-fish-images/images}"
    export CV_TEST_IMAGES
    if [[ ! -d "$CV_TEST_IMAGES" ]]; then
        echo "error: no image corpus at $CV_TEST_IMAGES" >&2
        echo "       Set CV_TEST_IMAGES to the folder holding KEMBUNG/, TENGGIRI/, ..." >&2
        exit 1
    fi
    echo "==> scanner tests will use $CV_TEST_IMAGES"
    exec "$0" --test "$@"
fi

# ------------------------------------------------------------------- port free
PORT=8000
for ((i = 1; i <= $#; i++)); do
    if [[ "${!i}" == "--port" ]]; then j=$((i + 1)); PORT="${!j}"; fi
done

if command -v lsof >/dev/null 2>&1 && lsof -ti:"$PORT" >/dev/null 2>&1; then
    echo "error: port $PORT is already in use — most likely an older server still" >&2
    echo "       running under the wrong interpreter. Stop it with:" >&2
    echo "           lsof -ti:$PORT | xargs kill" >&2
    exit 1
fi

# ------------------------------------------------------------------------- run
start_db
apply_schema_and_seed

echo "==> http://localhost:$PORT/docs"
exec "$PY" -m uvicorn app.main:app --reload --port "$PORT" "$@"
