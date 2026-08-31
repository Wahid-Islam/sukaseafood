-- =========================================================
-- 09_price_forecast.sql   ** GENERATED FILE — DO NOT EDIT **
-- =========================================================
-- Regenerate with:  cd backend && python scripts/generate_forecast_seed.py
--
-- Source of truth: backend/Price Forecast/ (Step 33A engine output).
-- Editing this file by hand desynchronises the app from the model run
-- that produced these numbers, and nothing would report the drift —
-- users would simply be shown a forecast no model ever made.
--
-- Production run: 2026-08-30T22:48:38Z
-- 48 forecast rows = 12 fish x 4 weeks, Selangor
--
-- Directional outlook distribution:
--   LIKELY_INCREASE     8 rows
--   LIKELY_DECREASE     4 rows
--   NO_STRONG_SIGNAL   36 rows
--
-- The NO_STRONG_SIGNAL majority is the expected result, not missing data.
-- The engine only claims a direction when validated evidence clears an
-- RM0.25 movement threshold. Nine of twelve fish do not clear it, and the
-- honest answer is that the price is as likely to go either way.
--
-- Rows resolve by name to a canonical seafood_item and are stored against
-- seafood_item_id, per 33B section 10 — the display name is a lookup key
-- only, never a foreign key. A name that does not resolve aborts the seed
-- rather than silently dropping a fish the app would then never forecast.
--
-- Idempotent: keyed on the engine's own forecast_id, so re-running a day's
-- refresh updates rows in place instead of accumulating duplicates.
--
-- Requires: schema/v3_forecast_contract.sql, 08_seafood_forecast_expansion.sql

BEGIN;

-- =========================================================
-- forecast_model_version — the selection policy
-- =========================================================
-- algorithm is MODEL_SELECTION_V1 because the engine picks per fish
-- between ETS(A,N,N) and NAIVE by walk-forward MAE. Which one won for a
-- given fish is recorded on each price_forecast row as model_used.

-- Only one version may be active: the serving query picks the active row,
-- and two would make the forecast the app shows depend on row order.
UPDATE forecast_model_version SET active = FALSE
 WHERE active AND version_name <> 'SukaSeafood Price Forecast Model Selection 2026-08-v1';

INSERT INTO forecast_model_version (
  forecast_model_version_id, version_name, algorithm, target_definition,
  training_window_start, training_window_end,
  validation_mae, validation_rmse, validation_mape,
  interval_level, configuration, active
) VALUES (
  suka_uuid5('forecast_model_version:SukaSeafood Price Forecast Model Selection 2026-08-v1'),
  'SukaSeafood Price Forecast Model Selection 2026-08-v1',
  'MODEL_SELECTION_V1',
  'One-week-ahead to four-week-ahead weekly seafood price outlook using validated per-fish model selection.',
  '2025-01-06'::date,
  '2026-08-17'::date,
  NULL,
  NULL,
  NULL,
  0.8000,
  '{
  "direction_method": "validated_direction_strategy",
  "direction_threshold": 0.25,
  "models": [
    "ETS(A,N,N)",
    "NAIVE"
  ],
  "range_method": "model_prediction_interval",
  "selection_method": "walk_forward_mae"
}'::jsonb,
  TRUE
)
ON CONFLICT (version_name) DO UPDATE SET
  algorithm             = EXCLUDED.algorithm,
  target_definition     = EXCLUDED.target_definition,
  training_window_start = EXCLUDED.training_window_start,
  training_window_end   = EXCLUDED.training_window_end,
  validation_mae        = EXCLUDED.validation_mae,
  validation_rmse       = EXCLUDED.validation_rmse,
  validation_mape       = EXCLUDED.validation_mape,
  interval_level        = EXCLUDED.interval_level,
  configuration         = EXCLUDED.configuration,
  active                = EXCLUDED.active;

-- Column mapping: the engine exports training_start_date /
-- training_end_date / validation_interval_level; V3 names those columns
-- training_window_start / training_window_end / interval_level.

-- =========================================================
-- Pre-flight: every forecast name must resolve
-- =========================================================
DO $$
DECLARE
  missing TEXT;
BEGIN
  SELECT string_agg(n, ', ') INTO missing
    FROM (VALUES
      ('Bawal Hitam'),
      ('Bawal Putih'),
      ('Cencaru'),
      ('Demuduk / Cupak / Cermin'),
      ('Ikan Merah'),
      ('Jenahak'),
      ('Kembung / Pelaling'),
      ('Kerisi'),
      ('Pelata'),
      ('Selar Kuning'),
      ('Siakap Putih'),
      ('Tenggiri')
    ) AS v(n)
   WHERE NOT EXISTS (
     SELECT 1 FROM seafood_item si WHERE si.canonical_name_ms = v.n)
  ;
  IF missing IS NOT NULL THEN
    RAISE EXCEPTION 'forecast fish with no canonical seafood_item row: %', missing;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM location
                  WHERE lower(state_name) = 'selangor' AND level = 'STATE') THEN
    RAISE EXCEPTION 'Selangor state location missing — forecast rows cannot resolve';
  END IF;
END $$;

-- =========================================================
-- price_forecast
-- =========================================================
INSERT INTO price_forecast (
  price_forecast_id, seafood_item_id, location_id, forecast_model_version_id,
  source_snapshot_id, forecast_origin_date, forecast_week_start, horizon_weeks,
  current_reference_price, expected_price, lower_bound, upper_bound,
  outlook, range_outlook, quality_status, model_used, generated_at
)
SELECT
  suka_uuid5('price_forecast:' || v.forecast_id),
  si.seafood_item_id,
  l.location_id,
  mv.forecast_model_version_id,
  suka_uuid5('source_snapshot:suka_forecast_engine:forecast-2026-08-v1'),
  v.forecast_origin_date::date,
  v.forecast_week_start::date,
  v.horizon_weeks::smallint,
  v.current_reference_price::numeric(12,2),
  v.expected_price::numeric(12,2),
  v.lower_bound::numeric(12,2),
  v.upper_bound::numeric(12,2),
  v.outlook,
  v.range_outlook,
  v.quality_status,
  v.model_used,
  v.generated_at::timestamptz
FROM (VALUES
  ('Bawal_Hitam_20260824', 'Bawal Hitam', 'Selangor', '2026-08-23', '2026-08-24', 1, 28.99, 28.67, 28.01, 29.34, 'LIKELY_DECREASE', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Bawal_Hitam_20260831', 'Bawal Hitam', 'Selangor', '2026-08-23', '2026-08-31', 2, 28.99, 28.67, 27.93, 29.42, 'LIKELY_DECREASE', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Bawal_Hitam_20260907', 'Bawal Hitam', 'Selangor', '2026-08-23', '2026-09-07', 3, 28.99, 28.67, 27.86, 29.49, 'LIKELY_DECREASE', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Bawal_Hitam_20260914', 'Bawal Hitam', 'Selangor', '2026-08-23', '2026-09-14', 4, 28.99, 28.67, 27.79, 29.56, 'LIKELY_DECREASE', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Bawal_Putih_20260824', 'Bawal Putih', 'Selangor', '2026-08-23', '2026-08-24', 1, 42.00, 43.17, 40.94, 45.39, 'LIKELY_INCREASE', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Bawal_Putih_20260831', 'Bawal Putih', 'Selangor', '2026-08-23', '2026-08-31', 2, 42.00, 43.17, 40.88, 45.45, 'LIKELY_INCREASE', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Bawal_Putih_20260907', 'Bawal Putih', 'Selangor', '2026-08-23', '2026-09-07', 3, 42.00, 43.17, 40.82, 45.51, 'LIKELY_INCREASE', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Bawal_Putih_20260914', 'Bawal Putih', 'Selangor', '2026-08-23', '2026-09-14', 4, 42.00, 43.17, 40.77, 45.56, 'LIKELY_INCREASE', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Cencaru_20260824', 'Cencaru', 'Selangor', '2026-08-23', '2026-08-24', 1, 10.00, 10.00, 9.10, 10.90, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Cencaru_20260831', 'Cencaru', 'Selangor', '2026-08-23', '2026-08-31', 2, 10.00, 10.00, 9.10, 10.90, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Cencaru_20260907', 'Cencaru', 'Selangor', '2026-08-23', '2026-09-07', 3, 10.00, 10.00, 9.10, 10.90, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Cencaru_20260914', 'Cencaru', 'Selangor', '2026-08-23', '2026-09-14', 4, 10.00, 10.00, 9.10, 10.90, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Demuduk_Cupak_Cermin_20260824', 'Demuduk / Cupak / Cermin', 'Selangor', '2026-08-23', '2026-08-24', 1, 32.00, 32.55, 31.64, 33.46, 'LIKELY_INCREASE', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Demuduk_Cupak_Cermin_20260831', 'Demuduk / Cupak / Cermin', 'Selangor', '2026-08-23', '2026-08-31', 2, 32.00, 32.55, 31.59, 33.51, 'LIKELY_INCREASE', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Demuduk_Cupak_Cermin_20260907', 'Demuduk / Cupak / Cermin', 'Selangor', '2026-08-23', '2026-09-07', 3, 32.00, 32.55, 31.54, 33.56, 'LIKELY_INCREASE', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Demuduk_Cupak_Cermin_20260914', 'Demuduk / Cupak / Cermin', 'Selangor', '2026-08-23', '2026-09-14', 4, 32.00, 32.55, 31.49, 33.60, 'LIKELY_INCREASE', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Ikan_Merah_20260824', 'Ikan Merah', 'Selangor', '2026-08-23', '2026-08-24', 1, 53.50, 53.39, 52.39, 54.39, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Ikan_Merah_20260831', 'Ikan Merah', 'Selangor', '2026-08-23', '2026-08-31', 2, 53.50, 53.47, 52.42, 54.52, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Ikan_Merah_20260907', 'Ikan Merah', 'Selangor', '2026-08-23', '2026-09-07', 3, 53.50, 53.55, 52.46, 54.64, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Ikan_Merah_20260914', 'Ikan Merah', 'Selangor', '2026-08-23', '2026-09-14', 4, 53.50, 53.63, 52.50, 54.76, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Jenahak_20260824', 'Jenahak', 'Selangor', '2026-08-23', '2026-08-24', 1, 45.99, 45.99, 45.14, 46.84, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Jenahak_20260831', 'Jenahak', 'Selangor', '2026-08-23', '2026-08-31', 2, 45.99, 45.99, 45.14, 46.84, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Jenahak_20260907', 'Jenahak', 'Selangor', '2026-08-23', '2026-09-07', 3, 45.99, 45.99, 45.14, 46.84, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Jenahak_20260914', 'Jenahak', 'Selangor', '2026-08-23', '2026-09-14', 4, 45.99, 45.99, 45.14, 46.84, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Kembung_Pelaling_20260824', 'Kembung / Pelaling', 'Selangor', '2026-08-23', '2026-08-24', 1, 15.90, 15.90, 14.89, 16.91, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Kembung_Pelaling_20260831', 'Kembung / Pelaling', 'Selangor', '2026-08-23', '2026-08-31', 2, 15.90, 15.90, 14.89, 16.91, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Kembung_Pelaling_20260907', 'Kembung / Pelaling', 'Selangor', '2026-08-23', '2026-09-07', 3, 15.90, 15.90, 14.89, 16.91, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Kembung_Pelaling_20260914', 'Kembung / Pelaling', 'Selangor', '2026-08-23', '2026-09-14', 4, 15.90, 15.90, 14.89, 16.91, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Kerisi_20260824', 'Kerisi', 'Selangor', '2026-08-23', '2026-08-24', 1, 16.99, 16.95, 16.25, 17.65, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Kerisi_20260831', 'Kerisi', 'Selangor', '2026-08-23', '2026-08-31', 2, 16.99, 16.95, 16.21, 17.69, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Kerisi_20260907', 'Kerisi', 'Selangor', '2026-08-23', '2026-09-07', 3, 16.99, 16.95, 16.17, 17.73, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Kerisi_20260914', 'Kerisi', 'Selangor', '2026-08-23', '2026-09-14', 4, 16.99, 16.95, 16.13, 17.77, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'ETS(A,N,N)', '2026-08-30T22:48:38Z'),
  ('Pelata_20260824', 'Pelata', 'Selangor', '2026-08-23', '2026-08-24', 1, 19.90, 19.90, 18.91, 20.89, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Pelata_20260831', 'Pelata', 'Selangor', '2026-08-23', '2026-08-31', 2, 19.90, 19.90, 18.91, 20.89, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Pelata_20260907', 'Pelata', 'Selangor', '2026-08-23', '2026-09-07', 3, 19.90, 19.90, 18.91, 20.89, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Pelata_20260914', 'Pelata', 'Selangor', '2026-08-23', '2026-09-14', 4, 19.90, 19.90, 18.91, 20.89, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Selar_Kuning_20260824', 'Selar Kuning', 'Selangor', '2026-08-23', '2026-08-24', 1, 13.40, 13.39, 12.78, 14.01, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Selar_Kuning_20260831', 'Selar Kuning', 'Selangor', '2026-08-23', '2026-08-31', 2, 13.40, 13.39, 12.78, 14.01, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Selar_Kuning_20260907', 'Selar Kuning', 'Selangor', '2026-08-23', '2026-09-07', 3, 13.40, 13.39, 12.78, 14.01, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Selar_Kuning_20260914', 'Selar Kuning', 'Selangor', '2026-08-23', '2026-09-14', 4, 13.40, 13.39, 12.78, 14.01, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'VALID', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Siakap_Putih_20260824', 'Siakap Putih', 'Selangor', '2026-08-23', '2026-08-24', 1, 20.00, 20.00, 19.10, 20.90, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Siakap_Putih_20260831', 'Siakap Putih', 'Selangor', '2026-08-23', '2026-08-31', 2, 20.00, 20.00, 19.10, 20.90, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Siakap_Putih_20260907', 'Siakap Putih', 'Selangor', '2026-08-23', '2026-09-07', 3, 20.00, 20.00, 19.10, 20.90, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Siakap_Putih_20260914', 'Siakap Putih', 'Selangor', '2026-08-23', '2026-09-14', 4, 20.00, 20.00, 19.10, 20.90, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Tenggiri_20260824', 'Tenggiri', 'Selangor', '2026-08-23', '2026-08-24', 1, 49.99, 49.99, 47.33, 52.65, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Tenggiri_20260831', 'Tenggiri', 'Selangor', '2026-08-23', '2026-08-31', 2, 49.99, 49.99, 47.33, 52.65, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Tenggiri_20260907', 'Tenggiri', 'Selangor', '2026-08-23', '2026-09-07', 3, 49.99, 49.99, 47.33, 52.65, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z'),
  ('Tenggiri_20260914', 'Tenggiri', 'Selangor', '2026-08-23', '2026-09-14', 4, 49.99, 49.99, 47.33, 52.65, 'NO_STRONG_SIGNAL', 'AROUND_CURRENT_LEVELS', 'SPARSE_DATA', 'NAIVE', '2026-08-30T22:48:38Z')
) AS v(forecast_id, canonical_name, location_name, forecast_origin_date,
       forecast_week_start, horizon_weeks, current_reference_price,
       expected_price, lower_bound, upper_bound, outlook, range_outlook,
       quality_status, model_used, generated_at)
JOIN seafood_item si ON si.canonical_name_ms = v.canonical_name
JOIN location l ON lower(l.state_name) = lower(v.location_name)
                AND l.level = 'STATE'
JOIN forecast_model_version mv ON mv.version_name = 'SukaSeafood Price Forecast Model Selection 2026-08-v1'
ON CONFLICT (price_forecast_id) DO UPDATE SET
  source_snapshot_id      = EXCLUDED.source_snapshot_id,
  forecast_origin_date    = EXCLUDED.forecast_origin_date,
  horizon_weeks           = EXCLUDED.horizon_weeks,
  current_reference_price = EXCLUDED.current_reference_price,
  expected_price          = EXCLUDED.expected_price,
  lower_bound             = EXCLUDED.lower_bound,
  upper_bound             = EXCLUDED.upper_bound,
  outlook                 = EXCLUDED.outlook,
  range_outlook           = EXCLUDED.range_outlook,
  quality_status          = EXCLUDED.quality_status,
  model_used              = EXCLUDED.model_used,
  generated_at            = EXCLUDED.generated_at;

-- =========================================================
-- Guard rails
-- =========================================================
DO $$
DECLARE
  n_rows  INT;
  n_fish  INT;
  n_short INT;
BEGIN
  SELECT count(*), count(DISTINCT pf.seafood_item_id) INTO n_rows, n_fish
    FROM price_forecast pf
    JOIN forecast_model_version mv USING (forecast_model_version_id)
   WHERE mv.active;

  IF n_rows <> 48 THEN
    RAISE EXCEPTION 'expected 48 active forecast rows, found %', n_rows;
  END IF;

  IF n_fish <> 12 THEN
    RAISE EXCEPTION 'expected 12 forecast fish, found % — a canonical name collapsed onto another', n_fish;
  END IF;

  -- A fish showing fewer than four weeks would render a truncated chart
  -- with nothing to tell the user weeks are missing.
  SELECT count(*) INTO n_short FROM (
    SELECT pf.seafood_item_id
      FROM price_forecast pf
      JOIN forecast_model_version mv USING (forecast_model_version_id)
     WHERE mv.active
     GROUP BY pf.seafood_item_id
    HAVING count(*) <> 4
  ) x;
  IF n_short > 0 THEN
    RAISE EXCEPTION '% fish do not have exactly 4 forecast weeks', n_short;
  END IF;
END $$;

COMMIT;
