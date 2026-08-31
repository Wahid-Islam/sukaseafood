-- =========================================================
-- SukaSeafood
-- Step 33B — Forecast Database / API Contract
-- =========================================================
--
-- PURPOSE
--   Align the V3 database with the production forecasting engine
--   and define the backend ingestion/upsert contract.
--
-- IMPORTANT
--   This script is a CONTRACT / IMPLEMENTATION TEMPLATE.
--   It does not run the R forecasting pipeline.
--
--   The R pipeline produces:
--       production_forecast_api.csv
--       db_price_forecast_staging.csv
--
--   The backend resolves database UUIDs and then inserts/upserts
--   rows into price_forecast.
--
-- =========================================================

-- =========================================================
-- 1. SCHEMA ALIGNMENT
-- =========================================================

-- Store the actual algorithm used for each individual forecast.
ALTER TABLE price_forecast
ADD COLUMN IF NOT EXISTS model_used TEXT;

-- Keep "NO_STRONG_SIGNAL" distinct from "STABLE".
ALTER TABLE price_forecast
DROP CONSTRAINT IF EXISTS price_forecast_outlook_check;

ALTER TABLE price_forecast
ADD CONSTRAINT price_forecast_outlook_check
CHECK (
    outlook IN (
        'LIKELY_INCREASE',
        'LIKELY_DECREASE',
        'NO_STRONG_SIGNAL'
    )
);

-- =========================================================
-- 2. PERFORMANCE INDEX
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_price_forecast_item_location_week
ON price_forecast (
    seafood_item_id,
    location_id,
    forecast_week_start
);

-- =========================================================
-- 3. MODEL VERSION
-- =========================================================
--
-- The deployed forecasting engine uses per-fish model selection:
--   ETS(A,N,N) OR NAIVE
--
-- Therefore the model-version row identifies the deployed
-- selection policy, while price_forecast.model_used records
-- the algorithm used for an individual fish.
--
-- =========================================================

INSERT INTO forecast_model_version (
    version_name,
    algorithm,
    target_definition,
    training_start_date,
    training_end_date,
    validation_mae,
    validation_rmse,
    validation_mape,
    validation_interval_level,
    configuration,
    active
)
VALUES (
    'SukaSeafood Price Forecast Model Selection 2026-08-v1',
    'MODEL_SELECTION_V1',
    'One-week-ahead to four-week-ahead weekly seafood price outlook using validated per-fish model selection.',
    DATE '2025-01-06',
    DATE '2026-08-17',
    NULL,
    NULL,
    NULL,
    0.80,
    '{
        "models": ["ETS(A,N,N)", "NAIVE"],
        "selection_method": "walk_forward_MAE",
        "direction_threshold_rm_per_kg": 0.25,
        "direction_method": "validated_direction_strategy",
        "range_method": "model_prediction_interval",
        "forecast_horizon_weeks": 4,
        "location_scope": "Selangor"
    }'::jsonb,
    TRUE
)
ON CONFLICT (version_name)
DO UPDATE SET
    algorithm = EXCLUDED.algorithm,
    target_definition = EXCLUDED.target_definition,
    training_start_date = EXCLUDED.training_start_date,
    training_end_date = EXCLUDED.training_end_date,
    validation_interval_level = EXCLUDED.validation_interval_level,
    configuration = EXCLUDED.configuration,
    active = EXCLUDED.active;

-- =========================================================
-- 4. STAGING TABLE
-- =========================================================

CREATE TEMP TABLE staging_price_forecast (
    forecast_id TEXT,
    canonical_name TEXT NOT NULL,
    location_name TEXT NOT NULL,
    model_version_name TEXT NOT NULL,
    model_algorithm TEXT,
    forecast_engine_version TEXT,
    forecast_origin_date DATE NOT NULL,
    forecast_week_start DATE NOT NULL,
    horizon_weeks SMALLINT NOT NULL,
    current_reference_price NUMERIC NOT NULL,
    expected_price NUMERIC NOT NULL,
    lower_bound NUMERIC NOT NULL,
    upper_bound NUMERIC NOT NULL,
    outlook TEXT NOT NULL,
    quality_status TEXT NOT NULL,
    model_used TEXT,
    generated_at TIMESTAMPTZ NOT NULL
);

-- =========================================================
-- 5. LOAD STAGING CSV
-- =========================================================
--
-- Example for psql:
--
-- \copy staging_price_forecast
-- FROM 'outputs/db_price_forecast_staging.csv'
-- CSV HEADER;
--
-- The backend may use its own CSV loader instead.
--
-- =========================================================

-- =========================================================
-- 6. VALIDATE FORECAST VALUES
-- =========================================================

DO $$
DECLARE
    bad_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO bad_count
    FROM staging_price_forecast
    WHERE
        lower_bound > upper_bound
        OR expected_price < lower_bound
        OR expected_price > upper_bound
        OR current_reference_price <= 0
        OR expected_price <= 0;

    IF bad_count > 0 THEN
        RAISE EXCEPTION
            'Invalid forecast range/value rows detected: %',
            bad_count;
    END IF;
END $$;

-- =========================================================
-- 7. VALIDATE FOUR WEEKS PER FISH
-- =========================================================

DO $$
DECLARE
    bad_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO bad_count
    FROM (
        SELECT
            canonical_name,
            COUNT(*) AS forecast_rows
        FROM staging_price_forecast
        GROUP BY canonical_name
        HAVING COUNT(*) <> 4
    ) x;

    IF bad_count > 0 THEN
        RAISE EXCEPTION
            'One or more fish do not have exactly four forecast rows.';
    END IF;
END $$;

-- =========================================================
-- 8. VALIDATE MODEL VERSION RESOLUTION
-- =========================================================

DO $$
DECLARE
    unresolved_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO unresolved_count
    FROM staging_price_forecast s
    LEFT JOIN forecast_model_version mv
        ON mv.version_name = s.model_version_name
    WHERE mv.forecast_model_version_id IS NULL;

    IF unresolved_count > 0 THEN
        RAISE EXCEPTION
            'Forecast rows reference an unresolved model version: %',
            unresolved_count;
    END IF;
END $$;

-- =========================================================
-- 9. VALIDATE SELANGOR LOCATION RESOLUTION
-- =========================================================
--
-- Adjust the lookup if the backend uses location_code or
-- another stable location identifier.
--
-- =========================================================

DO $$
DECLARE
    unresolved_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO unresolved_count
    FROM staging_price_forecast s
    LEFT JOIN location l
        ON LOWER(l.state_name) = LOWER(s.location_name)
    WHERE l.location_id IS NULL;

    IF unresolved_count > 0 THEN
        RAISE EXCEPTION
            'One or more forecast rows could not resolve their location: %',
            unresolved_count;
    END IF;
END $$;

-- =========================================================
-- 10. VALIDATE CANONICAL SEAFOOD RESOLUTION
-- =========================================================
--
-- canonical_name is only a lookup key.
-- The stored FK remains seafood_item_id.
--
-- =========================================================

DO $$
DECLARE
    unresolved_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO unresolved_count
    FROM staging_price_forecast s
    LEFT JOIN seafood_item si
        ON si.canonical_name_ms = s.canonical_name
    WHERE si.seafood_item_id IS NULL;

    IF unresolved_count > 0 THEN
        RAISE EXCEPTION
            'One or more forecast fish could not resolve to seafood_item_id: %',
            unresolved_count;
    END IF;
END $$;

-- =========================================================
-- 11. SOURCE SNAPSHOT
-- =========================================================
--
-- source_snapshot_id must reference the exact PriceCatcher
-- snapshot used to create the forecast.
--
-- The exact lookup depends on how the backend stores the
-- PriceCatcher release/version label.
--
-- DO NOT simply use the newest snapshot if it differs from
-- the snapshot that generated the forecast.
--
-- The backend should resolve:
--
--     :source_snapshot_id
--
-- before the INSERT below.
--
-- =========================================================

-- =========================================================
-- 12. INSERT / UPSERT PRICE FORECAST
-- =========================================================
--
-- Natural uniqueness:
--   seafood_item_id
--   location_id
--   forecast_model_version_id
--   forecast_week_start
--
-- Re-running the same model version for the same forecast week
-- therefore updates the existing row rather than duplicating it.
--
-- =========================================================

INSERT INTO price_forecast (
    price_forecast_id,
    seafood_item_id,
    location_id,
    forecast_model_version_id,
    source_snapshot_id,
    forecast_origin_date,
    forecast_week_start,
    horizon_weeks,
    current_reference_price,
    expected_price,
    lower_bound,
    upper_bound,
    outlook,
    quality_status,
    model_used,
    generated_at
)
SELECT
    gen_random_uuid(),
    si.seafood_item_id,
    l.location_id,
    mv.forecast_model_version_id,
    CAST(:source_snapshot_id AS UUID),
    s.forecast_origin_date,
    s.forecast_week_start,
    s.horizon_weeks,
    s.current_reference_price,
    s.expected_price,
    s.lower_bound,
    s.upper_bound,
    s.outlook,
    s.quality_status,
    s.model_used,
    s.generated_at
FROM staging_price_forecast s
JOIN seafood_item si
    ON si.canonical_name_ms = s.canonical_name
JOIN location l
    ON LOWER(l.state_name) = LOWER(s.location_name)
JOIN forecast_model_version mv
    ON mv.version_name = s.model_version_name
ON CONFLICT (
    seafood_item_id,
    location_id,
    forecast_model_version_id,
    forecast_week_start
)
DO UPDATE SET
    source_snapshot_id = EXCLUDED.source_snapshot_id,
    forecast_origin_date = EXCLUDED.forecast_origin_date,
    horizon_weeks = EXCLUDED.horizon_weeks,
    current_reference_price = EXCLUDED.current_reference_price,
    expected_price = EXCLUDED.expected_price,
    lower_bound = EXCLUDED.lower_bound,
    upper_bound = EXCLUDED.upper_bound,
    outlook = EXCLUDED.outlook,
    quality_status = EXCLUDED.quality_status,
    model_used = EXCLUDED.model_used,
    generated_at = EXCLUDED.generated_at;

-- =========================================================
-- 13. POST-INSERT VALIDATION
-- =========================================================

SELECT
    si.canonical_name_ms AS canonical_name,
    l.state_name,
    pf.forecast_week_start,
    pf.horizon_weeks,
    pf.current_reference_price,
    pf.expected_price,
    pf.lower_bound,
    pf.upper_bound,
    pf.outlook,
    pf.quality_status,
    pf.model_used,
    pf.generated_at
FROM price_forecast pf
JOIN seafood_item si
    ON si.seafood_item_id = pf.seafood_item_id
JOIN location l
    ON l.location_id = pf.location_id
JOIN forecast_model_version mv
    ON mv.forecast_model_version_id = pf.forecast_model_version_id
WHERE pf.forecast_week_start >= DATE '2026-08-24'
ORDER BY
    si.canonical_name_ms,
    pf.forecast_week_start;

-- =========================================================
-- 14. EXPECTED RESULT
-- =========================================================
--
-- 12 forecastable fish
-- × 4 forecast weeks
-- = 48 active forecast rows
--
-- =========================================================
