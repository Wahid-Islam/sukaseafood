#!/usr/bin/env python3
"""Turn the R forecasting engine's CSV output into db/seed/09_price_forecast.sql.

    cd backend && python scripts/generate_forecast_seed.py

Why a generated seed rather than a runtime CSV loader:

The repo's one way to get a working database is `db/apply.sh`. If the forecast
arrived through a separate Python ingestion step, a fresh clone would come up
with an empty price_forecast table and the app would show FORECAST_UNAVAILABLE
for every fish until someone remembered the extra command. Emitting SQL keeps
the forecast in the same idempotent, reviewable, CI-verifiable pipeline as
every other reference row. It is the same choice cv/scripts/register_model.py
makes for the CV class map.

Inputs, both from `backend/Price Forecast/` (Step 33A output):

    db_forecast_model_version_staging.csv   one row: the selection policy
    db_price_forecast_staging.csv           48 rows: 12 fish x 4 weeks
    production_forecast_api.csv             adds model_used and the labels

The two forecast files are joined on forecast_id. Neither is redundant: the
staging file carries the run origin and horizon that the database contract
requires, and the API file carries which estimator actually won for each fish,
which is only knowable per series.

Validation here mirrors 33B sections 6-7 and runs BEFORE any SQL is written, so
a bad engine run fails at generation time rather than at apply time.
"""

from __future__ import annotations

import csv
import json
import sys
from collections import defaultdict
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
FORECAST_DIR = BACKEND / "Price Forecast"
OUT_PATH = BACKEND / "db" / "seed" / "09_price_forecast.sql"

STAGING_CSV = FORECAST_DIR / "db_price_forecast_staging.csv"
MODEL_CSV = FORECAST_DIR / "db_forecast_model_version_staging.csv"
API_CSV = FORECAST_DIR / "production_forecast_api.csv"

HORIZON_WEEKS = 4

# The engine reports direction as a human label. The database stores a code, so
# that a copy edit to the label can never change what the data means.
DIRECTION_CODES = {
    "likely to increase": "LIKELY_INCREASE",
    "likely to decrease": "LIKELY_DECREASE",
    "no strong directional signal": "NO_STRONG_SIGNAL",
}

# NA / NaN / empty all mean "not measured" in R's CSV output.
NULLISH = {"", "na", "nan", "null", "none"}


class GenerationError(RuntimeError):
    """The engine output does not satisfy the contract. Nothing is written."""


def sql_str(value: str | None) -> str:
    """Quote a Postgres string literal, or emit NULL."""
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def sql_num(value: str | Decimal | None, places: int | None = None) -> str:
    if value is None or (isinstance(value, str) and value.strip().lower() in NULLISH):
        return "NULL"
    dec = Decimal(str(value).strip())
    if places is not None:
        dec = dec.quantize(Decimal(10) ** -places, rounding=ROUND_HALF_UP)
    return str(dec)


def sql_date(value: str | None) -> str:
    """A date literal, or NULL for R's NA."""
    if value is None or value.strip().lower() in NULLISH:
        return "NULL"
    return f"{sql_str(value.strip())}::date"


def money(value: str) -> Decimal:
    """Round to the NUMERIC(12,2) the column actually stores.

    Rounding here rather than letting Postgres do it means the bounds check is
    validated against the values that will really be persisted.
    """
    return Decimal(str(value).strip()).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise GenerationError(f"missing engine output: {path}")
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def load_model_version() -> dict[str, str]:
    rows = read_csv(MODEL_CSV)
    if len(rows) != 1:
        raise GenerationError(
            f"{MODEL_CSV.name} must describe exactly one model version, found {len(rows)}"
        )
    return rows[0]


def load_forecasts() -> list[dict]:
    """Join the staging and API exports, validate, and normalise."""
    staging = read_csv(STAGING_CSV)
    api_by_id = {row["forecast_id"]: row for row in read_csv(API_CSV)}

    if not staging:
        raise GenerationError(f"{STAGING_CSV.name} is empty")

    rows: list[dict] = []
    for row in staging:
        forecast_id = row["forecast_id"]
        api = api_by_id.get(forecast_id)
        if api is None:
            raise GenerationError(
                f"{forecast_id} is in {STAGING_CSV.name} but not {API_CSV.name}; "
                "the two exports came from different runs"
            )

        label = api["directional_outlook_label"].strip().lower()
        if label not in DIRECTION_CODES:
            raise GenerationError(
                f"{forecast_id}: unrecognised directional label "
                f"{api['directional_outlook_label']!r}. Valid production values are "
                f"{sorted(DIRECTION_CODES.values())}."
            )

        quality = row["quality_status"].strip().upper()
        if quality not in {"VALID", "SPARSE_DATA"}:
            raise GenerationError(
                f"{forecast_id}: quality_status {quality!r} is not VALID or SPARSE_DATA"
            )

        expected = money(row["expected_price"])
        lower = money(row["lower_bound"])
        upper = money(row["upper_bound"])
        reference = money(row["current_reference_price"])

        # 33B section 6, checked post-rounding.
        if not (lower <= expected <= upper):
            raise GenerationError(
                f"{forecast_id}: expected {expected} outside range [{lower}, {upper}]"
            )
        if reference <= 0 or expected <= 0:
            raise GenerationError(f"{forecast_id}: non-positive price")

        rows.append(
            {
                "forecast_id": forecast_id,
                "canonical_name": row["canonical_name"].strip(),
                "location_name": row["location_name"].strip(),
                "model_version_name": row["model_version_name"].strip(),
                "forecast_origin_date": row["forecast_origin_date"].strip(),
                "forecast_week_start": row["forecast_week_start"].strip(),
                "horizon_weeks": int(row["horizon_weeks"]),
                "current_reference_price": reference,
                "expected_price": expected,
                "lower_bound": lower,
                "upper_bound": upper,
                "outlook": DIRECTION_CODES[label],
                "range_outlook": row["outlook"].strip().upper(),
                "quality_status": quality,
                "model_used": api["model_used"].strip() or None,
                "generated_at": row["generated_at"].strip(),
            }
        )

    # 33B section 7: every fish gets the full horizon, or the app would render a
    # short chart with no indication that weeks are missing.
    per_fish: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        per_fish[row["canonical_name"]].append(row)
    for name, group in sorted(per_fish.items()):
        if len(group) != HORIZON_WEEKS:
            raise GenerationError(
                f"{name} has {len(group)} forecast rows, expected {HORIZON_WEEKS}"
            )
        horizons = sorted(r["horizon_weeks"] for r in group)
        if horizons != list(range(1, HORIZON_WEEKS + 1)):
            raise GenerationError(f"{name} has horizon weeks {horizons}, expected 1..4")

    versions = {row["model_version_name"] for row in rows}
    if len(versions) != 1:
        raise GenerationError(f"forecast rows span multiple model versions: {sorted(versions)}")

    rows.sort(key=lambda r: (r["canonical_name"], r["horizon_weeks"]))
    return rows


def normalise_configuration(raw: str) -> str:
    """Re-emit the engine's configuration JSON, or fail loudly.

    Passing it through json ensures apply.sh cannot fall over on a malformed
    blob halfway through a seed run.
    """
    try:
        return json.dumps(json.loads(raw), indent=2, sort_keys=True)
    except json.JSONDecodeError as exc:
        raise GenerationError(f"model version configuration is not valid JSON: {exc}") from exc


def render(model: dict[str, str], rows: list[dict]) -> str:
    version_name = model["forecast_model_version_name"].strip()
    fish = sorted({row["canonical_name"] for row in rows})
    directions: dict[str, int] = defaultdict(int)
    for row in rows:
        directions[row["outlook"]] += 1

    out: list[str] = []
    w = out.append

    w("-- =========================================================")
    w("-- 09_price_forecast.sql   ** GENERATED FILE — DO NOT EDIT **")
    w("-- =========================================================")
    w("-- Regenerate with:  cd backend && python scripts/generate_forecast_seed.py")
    w("--")
    w("-- Source of truth: backend/Price Forecast/ (Step 33A engine output).")
    w("-- Editing this file by hand desynchronises the app from the model run")
    w("-- that produced these numbers, and nothing would report the drift —")
    w("-- users would simply be shown a forecast no model ever made.")
    w("--")
    w(f"-- Production run: {rows[0]['generated_at']}")
    w(f"-- {len(rows)} forecast rows = {len(fish)} fish x {HORIZON_WEEKS} weeks, Selangor")
    w("--")
    w("-- Directional outlook distribution:")
    for code in ("LIKELY_INCREASE", "LIKELY_DECREASE", "NO_STRONG_SIGNAL"):
        count = directions.get(code, 0)
        w(f"--   {code:<18} {count:>2} rows")
    w("--")
    w("-- The NO_STRONG_SIGNAL majority is the expected result, not missing data.")
    w("-- The engine only claims a direction when validated evidence clears an")
    w("-- RM0.25 movement threshold. Nine of twelve fish do not clear it, and the")
    w("-- honest answer is that the price is as likely to go either way.")
    w("--")
    w("-- Rows resolve by name to a canonical seafood_item and are stored against")
    w("-- seafood_item_id, per 33B section 10 — the display name is a lookup key")
    w("-- only, never a foreign key. A name that does not resolve aborts the seed")
    w("-- rather than silently dropping a fish the app would then never forecast.")
    w("--")
    w("-- Idempotent: keyed on the engine's own forecast_id, so re-running a day's")
    w("-- refresh updates rows in place instead of accumulating duplicates.")
    w("--")
    w("-- Requires: schema/v3_forecast_contract.sql, 08_seafood_forecast_expansion.sql")
    w("")
    w("BEGIN;")
    w("")
    w("-- =========================================================")
    w("-- forecast_model_version — the selection policy")
    w("-- =========================================================")
    w("-- algorithm is MODEL_SELECTION_V1 because the engine picks per fish")
    w("-- between ETS(A,N,N) and NAIVE by walk-forward MAE. Which one won for a")
    w("-- given fish is recorded on each price_forecast row as model_used.")
    w("")
    w("-- Only one version may be active: the serving query picks the active row,")
    w("-- and two would make the forecast the app shows depend on row order.")
    w("UPDATE forecast_model_version SET active = FALSE")
    w(f" WHERE active AND version_name <> {sql_str(version_name)};")
    w("")
    w("INSERT INTO forecast_model_version (")
    w("  forecast_model_version_id, version_name, algorithm, target_definition,")
    w("  training_window_start, training_window_end,")
    w("  validation_mae, validation_rmse, validation_mape,")
    w("  interval_level, configuration, active")
    w(") VALUES (")
    w(f"  suka_uuid5('forecast_model_version:{version_name}'),")
    w(f"  {sql_str(version_name)},")
    w(f"  {sql_str(model['algorithm'].strip())},")
    w(f"  {sql_str(model['target_definition'].strip())},")
    w(f"  {sql_date(model['training_start_date'])},")
    w(f"  {sql_date(model['training_end_date'])},")
    w(f"  {sql_num(model['validation_mae'], 4)},")
    w(f"  {sql_num(model['validation_rmse'], 4)},")
    w(f"  {sql_num(model['validation_mape'], 4)},")
    w(f"  {sql_num(model['validation_interval_level'], 4)},")
    w(f"  {sql_str(normalise_configuration(model['configuration']))}::jsonb,")
    w("  TRUE")
    w(")")
    w("ON CONFLICT (version_name) DO UPDATE SET")
    w("  algorithm             = EXCLUDED.algorithm,")
    w("  target_definition     = EXCLUDED.target_definition,")
    w("  training_window_start = EXCLUDED.training_window_start,")
    w("  training_window_end   = EXCLUDED.training_window_end,")
    w("  validation_mae        = EXCLUDED.validation_mae,")
    w("  validation_rmse       = EXCLUDED.validation_rmse,")
    w("  validation_mape       = EXCLUDED.validation_mape,")
    w("  interval_level        = EXCLUDED.interval_level,")
    w("  configuration         = EXCLUDED.configuration,")
    w("  active                = EXCLUDED.active;")
    w("")

    # The training window column names differ between the engine's CSV and the
    # V3 schema; note the mapping where a reader will look for it.
    w("-- Column mapping: the engine exports training_start_date /")
    w("-- training_end_date / validation_interval_level; V3 names those columns")
    w("-- training_window_start / training_window_end / interval_level.")
    w("")
    w("-- =========================================================")
    w("-- Pre-flight: every forecast name must resolve")
    w("-- =========================================================")
    w("DO $$")
    w("DECLARE")
    w("  missing TEXT;")
    w("BEGIN")
    w("  SELECT string_agg(n, ', ') INTO missing")
    w("    FROM (VALUES")
    for index, name in enumerate(fish):
        comma = "," if index < len(fish) - 1 else ""
        w(f"      ({sql_str(name)}){comma}")
    w("    ) AS v(n)")
    w("   WHERE NOT EXISTS (")
    w("     SELECT 1 FROM seafood_item si WHERE si.canonical_name_ms = v.n)")
    w("  ;")
    w("  IF missing IS NOT NULL THEN")
    w("    RAISE EXCEPTION 'forecast fish with no canonical seafood_item row: %', missing;")
    w("  END IF;")
    w("")
    w("  IF NOT EXISTS (SELECT 1 FROM location")
    w("                  WHERE lower(state_name) = 'selangor' AND level = 'STATE') THEN")
    w("    RAISE EXCEPTION 'Selangor state location missing — forecast rows cannot resolve';")
    w("  END IF;")
    w("END $$;")
    w("")
    w("-- =========================================================")
    w("-- price_forecast")
    w("-- =========================================================")
    w("INSERT INTO price_forecast (")
    w("  price_forecast_id, seafood_item_id, location_id, forecast_model_version_id,")
    w("  source_snapshot_id, forecast_origin_date, forecast_week_start, horizon_weeks,")
    w("  current_reference_price, expected_price, lower_bound, upper_bound,")
    w("  outlook, range_outlook, quality_status, model_used, generated_at")
    w(")")
    w("SELECT")
    w("  suka_uuid5('price_forecast:' || v.forecast_id),")
    w("  si.seafood_item_id,")
    w("  l.location_id,")
    w("  mv.forecast_model_version_id,")
    w("  suka_uuid5('source_snapshot:suka_forecast_engine:forecast-2026-08-v1'),")
    w("  v.forecast_origin_date::date,")
    w("  v.forecast_week_start::date,")
    w("  v.horizon_weeks::smallint,")
    w("  v.current_reference_price::numeric(12,2),")
    w("  v.expected_price::numeric(12,2),")
    w("  v.lower_bound::numeric(12,2),")
    w("  v.upper_bound::numeric(12,2),")
    w("  v.outlook,")
    w("  v.range_outlook,")
    w("  v.quality_status,")
    w("  v.model_used,")
    w("  v.generated_at::timestamptz")
    w("FROM (VALUES")

    for index, row in enumerate(rows):
        comma = "," if index < len(rows) - 1 else ""
        w(
            "  ("
            + ", ".join(
                (
                    sql_str(row["forecast_id"]),
                    sql_str(row["canonical_name"]),
                    sql_str(row["location_name"]),
                    sql_str(row["forecast_origin_date"]),
                    sql_str(row["forecast_week_start"]),
                    str(row["horizon_weeks"]),
                    str(row["current_reference_price"]),
                    str(row["expected_price"]),
                    str(row["lower_bound"]),
                    str(row["upper_bound"]),
                    sql_str(row["outlook"]),
                    sql_str(row["range_outlook"]),
                    sql_str(row["quality_status"]),
                    sql_str(row["model_used"]),
                    sql_str(row["generated_at"]),
                )
            )
            + ")"
            + comma
        )

    w(") AS v(forecast_id, canonical_name, location_name, forecast_origin_date,")
    w("       forecast_week_start, horizon_weeks, current_reference_price,")
    w("       expected_price, lower_bound, upper_bound, outlook, range_outlook,")
    w("       quality_status, model_used, generated_at)")
    w("JOIN seafood_item si ON si.canonical_name_ms = v.canonical_name")
    w("JOIN location l ON lower(l.state_name) = lower(v.location_name)")
    w("                AND l.level = 'STATE'")
    w(f"JOIN forecast_model_version mv ON mv.version_name = {sql_str(version_name)}")
    w("ON CONFLICT (price_forecast_id) DO UPDATE SET")
    w("  source_snapshot_id      = EXCLUDED.source_snapshot_id,")
    w("  forecast_origin_date    = EXCLUDED.forecast_origin_date,")
    w("  horizon_weeks           = EXCLUDED.horizon_weeks,")
    w("  current_reference_price = EXCLUDED.current_reference_price,")
    w("  expected_price          = EXCLUDED.expected_price,")
    w("  lower_bound             = EXCLUDED.lower_bound,")
    w("  upper_bound             = EXCLUDED.upper_bound,")
    w("  outlook                 = EXCLUDED.outlook,")
    w("  range_outlook           = EXCLUDED.range_outlook,")
    w("  quality_status          = EXCLUDED.quality_status,")
    w("  model_used              = EXCLUDED.model_used,")
    w("  generated_at            = EXCLUDED.generated_at;")
    w("")
    w("-- =========================================================")
    w("-- Guard rails")
    w("-- =========================================================")
    w("DO $$")
    w("DECLARE")
    w("  n_rows  INT;")
    w("  n_fish  INT;")
    w("  n_short INT;")
    w("BEGIN")
    w("  SELECT count(*), count(DISTINCT pf.seafood_item_id) INTO n_rows, n_fish")
    w("    FROM price_forecast pf")
    w("    JOIN forecast_model_version mv USING (forecast_model_version_id)")
    w("   WHERE mv.active;")
    w("")
    w(f"  IF n_rows <> {len(rows)} THEN")
    w(
        f"    RAISE EXCEPTION 'expected {len(rows)} active forecast rows, found %'"
        ", n_rows;"
    )
    w("  END IF;")
    w("")
    w(f"  IF n_fish <> {len(fish)} THEN")
    w(
        f"    RAISE EXCEPTION 'expected {len(fish)} forecast fish, found % — a canonical "
        "name collapsed onto another', n_fish;"
    )
    w("  END IF;")
    w("")
    w("  -- A fish showing fewer than four weeks would render a truncated chart")
    w("  -- with nothing to tell the user weeks are missing.")
    w("  SELECT count(*) INTO n_short FROM (")
    w("    SELECT pf.seafood_item_id")
    w("      FROM price_forecast pf")
    w("      JOIN forecast_model_version mv USING (forecast_model_version_id)")
    w("     WHERE mv.active")
    w("     GROUP BY pf.seafood_item_id")
    w(f"    HAVING count(*) <> {HORIZON_WEEKS}")
    w("  ) x;")
    w("  IF n_short > 0 THEN")
    w(
        f"    RAISE EXCEPTION '% fish do not have exactly {HORIZON_WEEKS} forecast weeks'"
        ", n_short;"
    )
    w("  END IF;")
    w("END $$;")
    w("")
    w("COMMIT;")
    w("")

    return "\n".join(out)


def main() -> int:
    try:
        model = load_model_version()
        rows = load_forecasts()
        sql = render(model, rows)
    except GenerationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    OUT_PATH.write_text(sql, encoding="utf-8")
    fish_count = len({row["canonical_name"] for row in rows})
    print(f"wrote {OUT_PATH.relative_to(BACKEND)}: {len(rows)} rows, {fish_count} fish")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
