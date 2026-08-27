#!/bin/sh
# Runs once, automatically, on the first start of an empty Postgres volume.
#
# ORDER IS LOAD-BEARING and the files are listed explicitly rather than globbed.
# A glob would sort alphabetically and give i1_functions_indexes.sql BEFORE
# i1_initial_schema.sql, which fails: the functions file creates indexes on
# tables that do not exist yet. Seeds then depend on suka_uuid5() from the
# functions file, so all three stages must run in this order:
#
#   1. tables and enums
#   2. suka_uuid5() + constraints and indexes
#   3. reference data
#
# Keep this list in sync with backend/db/apply.sh, which applies the same files
# in the same order to a database that already exists.
set -e

DB_DIR=/opt/sukaseafood/db

run() {
  echo "==> $(basename "$1")"
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$1"
}

run "$DB_DIR/schema/i1_initial_schema.sql"
run "$DB_DIR/schema/i1_functions_indexes.sql"

for f in "$DB_DIR"/seed/*.sql; do
  [ -e "$f" ] || continue
  run "$f"
done

echo "==> verifying"
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$DB_DIR/verify.sql"
