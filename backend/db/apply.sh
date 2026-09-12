#!/usr/bin/env bash
# Apply the SukaSeafood V3 schema and reference seed to a PostgreSQL database.
#
#   ./apply.sh                                   # uses $DATABASE_URL or the local default
#   DATABASE_URL=postgresql://... ./apply.sh     # explicit target (e.g. Cloud SQL)
#   ./apply.sh --schema-only                     # structure, no seed data
#
# Every file is idempotent, so re-running is safe and is the normal way to pick
# up new reference rows.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB="${DATABASE_URL:-postgresql://sukaseafood:sukaseafood@localhost:5432/sukaseafood}"

# The app talks asyncpg; psql does not understand the +asyncpg / +psycopg suffix.
DB="$(printf '%s' "$DB" | sed -E 's#^postgresql\+[a-z0-9_]+://#postgresql://#')"

SCHEMA_ONLY=0
[ "${1:-}" = "--schema-only" ] && SCHEMA_ONLY=1

run() {
  echo "==> $(basename "$1")"
  psql "$DB" -v ON_ERROR_STOP=1 -q -f "$1"
}

echo "Target: $(printf '%s' "$DB" | sed -E 's#://[^@]*@#://***@#')"

run "$DIR/schema/v3_initial_schema.sql"
run "$DIR/schema/v3_migrate_from_i1.sql"
run "$DIR/schema/v3_functions_indexes.sql"
run "$DIR/schema/v3_forecast_contract.sql"
run "$DIR/schema/i1_app_user.sql"
run "$DIR/schema/v3_user_prefs.sql"
run "$DIR/schema/v3_biodiversity.sql"

if [ "$SCHEMA_ONLY" -eq 0 ]; then
  for f in "$DIR"/seed/*.sql; do
    run "$f"
  done
fi

echo
psql "$DB" -v ON_ERROR_STOP=1 -f "$DIR/verify.sql"
