-- SukaSeafood Iteration 1 — operational functions, constraints and indexes.
--
-- Applied AFTER i1_initial_schema.sql. Everything here is additive: it does not
-- change any column defined in the handoff design. It exists because the base
-- DDL alone is not operable:
--
--   * seeds need stable primary keys across environments (suka_uuid5)
--   * seeds need natural-key uniqueness to be re-runnable (ON CONFLICT targets)
--   * the API's hot read paths need supporting indexes on foreign keys
--
-- Idempotent: safe to re-run.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================================
-- Deterministic id generation
-- =========================================================
--
-- Reference rows (locations, data sources, cooking methods, the 5 canonical
-- species) must carry the SAME uuid in every environment — local Docker, CI,
-- and Supabase — because price_summary, price_trend_point and the CV class map
-- all reference them by id. gen_random_uuid() would produce a different key per
-- environment and make rollups non-portable.
--
-- suka_uuid5('seafood_item:SF001') is a UUID version 5 over a fixed namespace,
-- byte-for-byte identical to Python's:
--
--   uuid.uuid5(uuid.UUID('6f9619ff-8b86-d011-b42d-00c04fc964ff'), 'seafood_item:SF001')
--
-- so ETL written in Python and SQL seeds agree on keys without coordination.

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
             set_byte(b, 6, (get_byte(b, 6) & 15) | 80),   -- version 5
             8, (get_byte(b, 8) & 63) | 128                -- RFC 4122 variant
           ),
           'hex'
         )::uuid
  FROM h;
$fn$;

COMMENT ON FUNCTION suka_uuid5(TEXT) IS
  'Deterministic UUIDv5 over the SukaSeafood namespace. Matches Python uuid.uuid5 with namespace 6f9619ff-8b86-d011-b42d-00c04fc964ff.';

-- =========================================================
-- Natural-key uniqueness (makes seeds and ETL idempotent)
-- =========================================================

-- A state appears once; a district appears once within its state.
CREATE UNIQUE INDEX IF NOT EXISTS uq_location_state
  ON location (state_name)
  WHERE level = 'STATE';

CREATE UNIQUE INDEX IF NOT EXISTS uq_location_district
  ON location (state_name, district_name)
  WHERE level = 'DISTRICT';

-- One assessment per species per source snapshot: re-running the WWF import
-- updates in place instead of duplicating ratings.
CREATE UNIQUE INDEX IF NOT EXISTS uq_wwf_assessment_natural
  ON wwf_assessment (seafood_item_id, source_snapshot_id, source_record_key);

-- One snapshot per source per version label.
CREATE UNIQUE INDEX IF NOT EXISTS uq_source_snapshot_version
  ON source_snapshot (data_source_id, version_label);

-- One recipe per external id per snapshot.
CREATE UNIQUE INDEX IF NOT EXISTS uq_recipe_external
  ON recipe (source_snapshot_id, external_recipe_id);

-- =========================================================
-- Read-path indexes
-- =========================================================
-- Postgres indexes primary keys and unique constraints automatically but NOT
-- foreign keys. Every index below backs a query the I1 API actually issues.

-- GET /seafood/{id} -> aliases, cooking, sustainability fan-out
CREATE INDEX IF NOT EXISTS idx_seafood_alias_item
  ON seafood_alias (seafood_item_id);

CREATE INDEX IF NOT EXISTS idx_wwf_assessment_item
  ON wwf_assessment (seafood_item_id);

CREATE INDEX IF NOT EXISTS idx_cooking_suitability_item
  ON cooking_suitability (seafood_item_id);

-- GET /cooking/{method} -> best species for a method, highest score first
CREATE INDEX IF NOT EXISTS idx_cooking_suitability_method_score
  ON cooking_suitability (cooking_method_id, suitability_score DESC);

-- GET /seafood/{id}/price -> species -> pricecatcher item -> summary
CREATE INDEX IF NOT EXISTS idx_price_item_mapping_item
  ON price_item_mapping (seafood_item_id, priority);

CREATE INDEX IF NOT EXISTS idx_price_item_mapping_pc_item
  ON price_item_mapping (pricecatcher_item_id);

-- "latest displayable summary for this item in this location"
CREATE INDEX IF NOT EXISTS idx_price_summary_lookup
  ON price_summary (pricecatcher_item_id, location_id, window_days, period_end DESC);

-- 12-week trend chart, ordered by week
CREATE INDEX IF NOT EXISTS idx_price_trend_lookup
  ON price_trend_point (pricecatcher_item_id, location_id, week_start DESC);

-- Landings context by month/scope
CREATE INDEX IF NOT EXISTS idx_supply_landing_period
  ON supply_landing_point (period_month DESC, scope_level, state_name);

-- Recipe joins
CREATE INDEX IF NOT EXISTS idx_recipe_seafood_mapping_seafood
  ON recipe_seafood_mapping (seafood_item_id);

CREATE INDEX IF NOT EXISTS idx_recipe_cooking_method_method
  ON recipe_cooking_method (cooking_method_id);

-- Snapshot lineage: "which rows came from this import?"
CREATE INDEX IF NOT EXISTS idx_source_snapshot_source
  ON source_snapshot (data_source_id, retrieved_at DESC);

COMMIT;
