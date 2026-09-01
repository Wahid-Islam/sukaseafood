#!/bin/sh
# Runs once, automatically, on the first start of an empty Postgres volume.
#
# ORDER IS LOAD-BEARING. Keep in sync with backend/db/apply.sh.
set -e

DB_DIR=/opt/sukaseafood/db

run() {
  echo "==> $(basename "$1")"
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$1"
}

run "$DB_DIR/schema/v3_initial_schema.sql"
run "$DB_DIR/schema/v3_migrate_from_i1.sql"
run "$DB_DIR/schema/v3_functions_indexes.sql"
run "$DB_DIR/schema/v3_forecast_contract.sql"
run "$DB_DIR/schema/i1_app_user.sql"
run "$DB_DIR/schema/v3_user_prefs.sql"

for f in "$DB_DIR"/seed/*.sql; do
  [ -e "$f" ] || continue
  run "$f"
done

echo "==> verifying"
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$DB_DIR/verify.sql"
