-- SukaSeafood V3 — operational functions, constraints and indexes.
--
-- Applied AFTER v3_initial_schema.sql. Additive only.
-- Idempotent: safe to re-run.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================================
-- Deterministic id generation
-- =========================================================
--
-- Reference rows must carry the SAME uuid in every environment.
-- suka_uuid5('seafood_item:SF001') matches Python:
--   uuid.uuid5(uuid.UUID('6f9619ff-8b86-d011-b42d-00c04fc964ff'), 'seafood_item:SF001')

CREATE OR REPLACE FUNCTION suka_uuid5(p_name TEXT)
RETURNS UUID
LANGUAGE sql
IMMUTABLE
STRICT
AS $fn$
  WITH h AS (
    SELECT substring(
             digest(
               decode('6f9619ff8b86d011b42d00c04fc964ff', 'hex') || convert_to(p_name, 'utf8'),
               'sha1'
             )
             FROM 1 FOR 16
           ) AS b
  )
  SELECT encode(
           set_byte(
             set_byte(b, 6, (get_byte(b, 6) & 15) | 80),
             8, (get_byte(b, 8) & 63) | 128
           ),
           'hex'
         )::uuid
  FROM h;
$fn$;

COMMENT ON FUNCTION suka_uuid5(TEXT) IS
  'Deterministic UUIDv5 over the SukaSeafood namespace. Matches Python uuid.uuid5 with namespace 6f9619ff-8b86-d011-b42d-00c04fc964ff.';

-- =========================================================
-- Natural-key uniqueness
-- =========================================================

CREATE UNIQUE INDEX IF NOT EXISTS uq_location_state
  ON location (state_name)
  WHERE level = 'STATE';

CREATE UNIQUE INDEX IF NOT EXISTS uq_location_district
  ON location (state_name, district_name)
  WHERE level = 'DISTRICT';

CREATE UNIQUE INDEX IF NOT EXISTS uq_source_snapshot_version
  ON source_snapshot (data_source_id, version_label);

CREATE UNIQUE INDEX IF NOT EXISTS uq_recipe_external
  ON recipe (source_snapshot_id, external_recipe_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_cv_class_mapping_index
  ON cv_class_mapping (cv_model_version_id, model_class_index);

-- =========================================================
-- Read-path indexes
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_seafood_item_scientific_normalized
  ON seafood_item (scientific_name_normalized)
  WHERE scientific_name_normalized IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_seafood_alias_item
  ON seafood_alias (seafood_item_id);

CREATE INDEX IF NOT EXISTS idx_wwf_assessment_item
  ON wwf_assessment (seafood_item_id);

CREATE INDEX IF NOT EXISTS idx_cooking_suitability_item
  ON cooking_suitability (seafood_item_id);

CREATE INDEX IF NOT EXISTS idx_cooking_suitability_method_score
  ON cooking_suitability (cooking_method_id, suitability_score DESC);

CREATE INDEX IF NOT EXISTS idx_price_item_mapping_item
  ON price_item_mapping (seafood_item_id, priority);

CREATE INDEX IF NOT EXISTS idx_price_item_mapping_pc_item
  ON price_item_mapping (pricecatcher_item_id);

CREATE INDEX IF NOT EXISTS idx_pricecatcher_premise_location
  ON pricecatcher_premise (location_id);

CREATE INDEX IF NOT EXISTS idx_price_period_summary_lookup
  ON price_period_summary (
    seafood_item_id, location_id, period_type, period_end DESC
  );

CREATE INDEX IF NOT EXISTS idx_price_trend_lookup
  ON price_trend_point (seafood_item_id, location_id, week_start DESC);

CREATE INDEX IF NOT EXISTS idx_price_forecast_lookup
  ON price_forecast (
    seafood_item_id, location_id, forecast_model_version_id, forecast_week_start DESC
  );

CREATE INDEX IF NOT EXISTS idx_supply_landing_period
  ON supply_landing_point (period_month DESC, scope_level, state_name);

CREATE INDEX IF NOT EXISTS idx_cv_class_mapping_seafood
  ON cv_class_mapping (seafood_item_id);

CREATE INDEX IF NOT EXISTS idx_recipe_seafood_mapping_seafood
  ON recipe_seafood_mapping (seafood_item_id);

CREATE INDEX IF NOT EXISTS idx_recipe_cooking_method_method
  ON recipe_cooking_method (cooking_method_id);

CREATE INDEX IF NOT EXISTS idx_source_snapshot_source
  ON source_snapshot (data_source_id, retrieved_at DESC);

COMMIT;
