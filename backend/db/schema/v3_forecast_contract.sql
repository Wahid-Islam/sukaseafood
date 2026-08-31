-- =========================================================
-- v3_forecast_contract.sql — Step 33B schema alignment
-- =========================================================
-- Additive ALTERs applied after v3_initial_schema.sql. Kept in its own file
-- for the same reason i1_app_user.sql is: v3_initial_schema.sql records the
-- reviewed V3 contract, and the R forecasting engine was specified after it
-- was frozen. Editing the frozen file would hide that sequence.
--
-- What the engine produces that V3 had nowhere to put:
--   * the reference price each forecast was made from, so the app can show
--     "expected 15.90, currently 15.90" without a second query
--   * which run produced the row (forecast_origin_date) and how far ahead it
--     reaches (horizon_weeks)
--   * the algorithm actually chosen for THIS fish. Model selection is
--     per-fish — ETS(A,N,N) or NAIVE — so forecast_model_version records the
--     selection POLICY and model_used records the outcome for one series.
--   * how much recent PriceCatcher data backed it (VALID / SPARSE_DATA)
--   * the snapshot the forecast was computed from
--
-- The two outlook columns are deliberate. The engine emits two different
-- readings of the same forecast and collapsing them would lose information:
--
--   outlook        directional verdict, RM0.25 movement threshold, emitted
--                  only when validated evidence supports it
--   range_outlook  where the forecast band sits against the reference price
--
-- NO_STRONG_SIGNAL is not STABLE. It means the evidence did not justify
-- telling a shopper the price will move. Nine of the twelve production fish
-- are in that state; that is the honest result, not a gap to be filled.
--
-- Idempotent: safe to re-run via apply.sh.

BEGIN;

-- =========================================================
-- 1. price_forecast — engine columns
-- =========================================================

ALTER TABLE price_forecast
  ADD COLUMN IF NOT EXISTS source_snapshot_id UUID
    REFERENCES source_snapshot(source_snapshot_id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS forecast_origin_date DATE,
  ADD COLUMN IF NOT EXISTS horizon_weeks SMALLINT,
  ADD COLUMN IF NOT EXISTS current_reference_price NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS range_outlook TEXT,
  ADD COLUMN IF NOT EXISTS quality_status TEXT,
  ADD COLUMN IF NOT EXISTS model_used TEXT;

-- DROP-then-ADD rather than a bare ADD: CHECK constraints have no
-- IF NOT EXISTS form, and this file must survive being re-run.
ALTER TABLE price_forecast
  DROP CONSTRAINT IF EXISTS price_forecast_outlook_check;

ALTER TABLE price_forecast
  ADD CONSTRAINT price_forecast_outlook_check CHECK (
    outlook IS NULL
    OR outlook IN ('LIKELY_INCREASE', 'LIKELY_DECREASE', 'NO_STRONG_SIGNAL')
  );

ALTER TABLE price_forecast
  DROP CONSTRAINT IF EXISTS price_forecast_quality_status_check;

ALTER TABLE price_forecast
  ADD CONSTRAINT price_forecast_quality_status_check CHECK (
    quality_status IS NULL OR quality_status IN ('VALID', 'SPARSE_DATA')
  );

ALTER TABLE price_forecast
  DROP CONSTRAINT IF EXISTS price_forecast_horizon_weeks_check;

ALTER TABLE price_forecast
  ADD CONSTRAINT price_forecast_horizon_weeks_check CHECK (
    horizon_weeks IS NULL OR horizon_weeks > 0
  );

ALTER TABLE price_forecast
  DROP CONSTRAINT IF EXISTS price_forecast_reference_price_check;

ALTER TABLE price_forecast
  ADD CONSTRAINT price_forecast_reference_price_check CHECK (
    current_reference_price IS NULL OR current_reference_price > 0
  );

-- =========================================================
-- 2. forecast_model_version — what the version targets
-- =========================================================
-- The staging CSV carries a prose target definition. Without a column for it
-- the only record of what a version forecasts would be its name.

ALTER TABLE forecast_model_version
  ADD COLUMN IF NOT EXISTS target_definition TEXT;

-- =========================================================
-- 3. Serving index
-- =========================================================
-- idx_price_forecast_lookup has forecast_model_version_id in third position,
-- so the app's actual query — one fish, one location, ordered by week, model
-- version resolved separately — cannot use it past the second column.

CREATE INDEX IF NOT EXISTS idx_price_forecast_item_location_week
  ON price_forecast (seafood_item_id, location_id, forecast_week_start);

COMMIT;
