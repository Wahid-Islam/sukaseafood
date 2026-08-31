-- SukaSeafood Database Schema V3
-- PostgreSQL DDL — structure only.
--
-- Canonical contract: seafood_item is the hub. Source-specific and feature-
-- specific records are spokes. External IDs (PriceCatcher item_code,
-- premise_code, WWF source rows, CV labels) are NEVER the application
-- canonical seafood ID.
--
-- Apply order (see apply.sh / docker-initdb):
--   1. schema/v3_initial_schema.sql      <- this file
--   2. schema/v3_functions_indexes.sql
--   3. schema/i1_app_user.sql            <- app accounts (unchanged)
--   4. seed/*.sql
--
-- Idempotent: safe to re-run on an empty or partially-applied database.

BEGIN;

-- Managed PostgreSQL (Cloud SQL) withholds CREATE on the database from ordinary
-- roles, so an unconditional CREATE EXTENSION aborts the whole apply. Both
-- extensions are optional: gen_random_uuid() is core since PostgreSQL 13, and
-- suka_uuid5() in v3_functions_indexes.sql accepts either uuid-ossp or pgcrypto.
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pgcrypto;
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'pgcrypto not installable by %; continuing without it.', current_user;
END $$;

DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EXCEPTION WHEN insufficient_privilege THEN
  RAISE NOTICE 'uuid-ossp not installable by %; continuing without it.', current_user;
END $$;

SET search_path TO public;

-- =========================================================
-- ENUMS
-- =========================================================

DO $$ BEGIN
  CREATE TYPE location_level_enum AS ENUM ('STATE', 'DISTRICT');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE seafood_alias_type_enum AS ENUM
    ('MALAY', 'ENGLISH_COMMON', 'SCIENTIFIC', 'MARKET', 'SPELLING');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE collection_method_enum AS ENUM
    ('OFFICIAL_DOWNLOAD', 'MANUAL_PDF_TRANSCRIPTION', 'TEAM_CURATED', 'MODEL_ARTIFACT');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE sustainability_rating_enum AS ENUM
    ('BEST_CHOICE', 'REDUCE', 'AVOID');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE product_form_enum AS ENUM
    ('WHOLE', 'CUT', 'FILLET', 'HEAD', 'COOKED', 'OTHER');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE price_mapping_type_enum AS ENUM
    ('EXACT', 'COMMON_NAME', 'MARKET_VARIANT', 'MARKET_GROUP', 'PROXY');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Add PROXY if upgrading from I1 enum that lacked it.
DO $$ BEGIN
  ALTER TYPE price_mapping_type_enum ADD VALUE IF NOT EXISTS 'PROXY';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE aggregation_rule_enum AS ENUM
    ('SEPARATE', 'COMBINE', 'DEFAULT_ONLY', 'PROXY');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE mapping_confidence_enum AS ENUM
    ('HIGH', 'MEDIUM', 'LOW');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE price_quality_enum AS ENUM
    ('DISPLAYABLE', 'INSUFFICIENT_DATA', 'REJECTED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE period_type_enum AS ENUM
    ('WEEK', 'MONTH', 'QUARTER');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE recipe_mapping_type_enum AS ENUM
    ('EXACT', 'COMMON_NAME', 'MANUAL_CURATED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- =========================================================
-- 1. location
-- =========================================================

CREATE TABLE IF NOT EXISTS location (
  location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_location_id UUID REFERENCES location(location_id) ON DELETE RESTRICT,
  level location_level_enum NOT NULL,
  state_name TEXT NOT NULL,
  district_name TEXT,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

-- =========================================================
-- 2. seafood_item  (canonical hub)
-- =========================================================

CREATE TABLE IF NOT EXISTS seafood_item (
  seafood_item_id UUID PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  canonical_name_ms TEXT NOT NULL,
  display_name_en TEXT NOT NULL,
  scientific_name TEXT NOT NULL,
  scientific_name_normalized TEXT,
  taxonomic_level TEXT NOT NULL,
  family TEXT,
  fish_type TEXT NOT NULL,
  description TEXT NOT NULL,
  supports_cv BOOLEAN NOT NULL DEFAULT FALSE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  primary_image_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- 3. seafood_alias
-- =========================================================

CREATE TABLE IF NOT EXISTS seafood_alias (
  seafood_alias_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL
    REFERENCES seafood_item(seafood_item_id) ON DELETE RESTRICT,
  alias_name TEXT NOT NULL,
  language_code TEXT,
  alias_type seafood_alias_type_enum NOT NULL,
  verified BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_seafood_alias_search
  ON seafood_alias (LOWER(TRIM(alias_name)));

CREATE UNIQUE INDEX IF NOT EXISTS uq_seafood_alias_per_seafood
  ON seafood_alias (seafood_item_id, LOWER(TRIM(alias_name)));

-- =========================================================
-- 4. data_source
-- =========================================================

CREATE TABLE IF NOT EXISTS data_source (
  data_source_id UUID PRIMARY KEY,
  source_key TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  owner TEXT,
  type TEXT NOT NULL,
  homepage_url TEXT,
  license TEXT,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

-- =========================================================
-- 5. source_snapshot
-- =========================================================

CREATE TABLE IF NOT EXISTS source_snapshot (
  source_snapshot_id UUID PRIMARY KEY,
  data_source_id UUID NOT NULL
    REFERENCES data_source(data_source_id) ON DELETE RESTRICT,
  version_label TEXT NOT NULL,
  source_period_start DATE,
  source_period_end DATE,
  retrieved_at TIMESTAMPTZ NOT NULL,
  collection_method collection_method_enum NOT NULL,
  manifest JSONB,
  notes TEXT
);

-- =========================================================
-- 6. wwf_assessment  (1:N from seafood_item — context-dependent ratings)
-- =========================================================

CREATE TABLE IF NOT EXISTS wwf_assessment (
  wwf_assessment_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL
    REFERENCES seafood_item(seafood_item_id) ON DELETE RESTRICT,
  source_snapshot_id UUID NOT NULL
    REFERENCES source_snapshot(source_snapshot_id) ON DELETE RESTRICT,
  source_record_key TEXT NOT NULL,
  common_name_raw TEXT NOT NULL,
  secondary_common_name_raw TEXT,
  scientific_name_raw TEXT NOT NULL,
  rating sustainability_rating_enum NOT NULL,
  origin_raw TEXT,
  origin_code TEXT,
  production_type TEXT,
  production_method_raw TEXT,
  production_method_code TEXT,
  certification_raw TEXT,
  context TEXT,
  notes_raw TEXT,
  UNIQUE (source_snapshot_id, source_record_key)
);

-- =========================================================
-- 7. pricecatcher_item
-- =========================================================

CREATE TABLE IF NOT EXISTS pricecatcher_item (
  pricecatcher_item_id UUID PRIMARY KEY,
  source_snapshot_id UUID NOT NULL
    REFERENCES source_snapshot(source_snapshot_id) ON DELETE RESTRICT,
  external_item_code TEXT NOT NULL UNIQUE,
  official_item_name TEXT NOT NULL,
  unit_raw TEXT NOT NULL,
  unit_code TEXT NOT NULL,
  item_group TEXT,
  item_category TEXT,
  product_form product_form_enum NOT NULL,
  size_descriptor TEXT,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

-- =========================================================
-- 8. pricecatcher_premise
-- =========================================================

CREATE TABLE IF NOT EXISTS pricecatcher_premise (
  pricecatcher_premise_id UUID PRIMARY KEY,
  source_snapshot_id UUID NOT NULL
    REFERENCES source_snapshot(source_snapshot_id) ON DELETE RESTRICT,
  location_id UUID NOT NULL
    REFERENCES location(location_id) ON DELETE RESTRICT,
  external_premise_code TEXT NOT NULL UNIQUE,
  premise_name TEXT NOT NULL,
  retail_class TEXT NOT NULL,
  address_raw TEXT,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

-- =========================================================
-- 9. price_item_mapping  (canonical seafood ↔ PriceCatcher item)
-- =========================================================

CREATE TABLE IF NOT EXISTS price_item_mapping (
  price_item_mapping_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL
    REFERENCES seafood_item(seafood_item_id) ON DELETE RESTRICT,
  pricecatcher_item_id UUID NOT NULL
    REFERENCES pricecatcher_item(pricecatcher_item_id) ON DELETE RESTRICT,
  mapping_type price_mapping_type_enum NOT NULL,
  priority SMALLINT NOT NULL CHECK (priority > 0),
  is_default_for_generic BOOLEAN NOT NULL DEFAULT FALSE,
  requires_variant_confirmation BOOLEAN NOT NULL DEFAULT FALSE,
  aggregation_rule aggregation_rule_enum NOT NULL DEFAULT 'SEPARATE',
  mapping_confidence mapping_confidence_enum NOT NULL DEFAULT 'MEDIUM',
  notes TEXT,
  UNIQUE (seafood_item_id, pricecatcher_item_id)
);

-- =========================================================
-- 10. price_period_summary  (keyed by seafood_item_id — derived layer)
-- =========================================================

CREATE TABLE IF NOT EXISTS price_period_summary (
  price_period_summary_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL
    REFERENCES seafood_item(seafood_item_id) ON DELETE RESTRICT,
  location_id UUID NOT NULL
    REFERENCES location(location_id) ON DELETE RESTRICT,
  source_snapshot_id UUID NOT NULL
    REFERENCES source_snapshot(source_snapshot_id) ON DELETE RESTRICT,
  location_level location_level_enum NOT NULL,
  period_type period_type_enum NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  median_price NUMERIC(12,2) NOT NULL,
  average_price NUMERIC(12,2),
  min_price NUMERIC(12,2),
  max_price NUMERIC(12,2),
  p25_price NUMERIC(12,2),
  p75_price NUMERIC(12,2),
  observation_count INTEGER NOT NULL CHECK (observation_count >= 0),
  premise_count INTEGER NOT NULL CHECK (premise_count >= 0),
  distinct_day_count INTEGER NOT NULL CHECK (distinct_day_count >= 0),
  quality_status price_quality_enum NOT NULL,
  calculation_version TEXT NOT NULL,
  calculated_at TIMESTAMPTZ NOT NULL,
  UNIQUE (
    seafood_item_id,
    location_id,
    period_type,
    period_start,
    period_end,
    calculation_version
  )
);

-- =========================================================
-- 11. price_trend_point  (keyed by seafood_item_id)
-- =========================================================

CREATE TABLE IF NOT EXISTS price_trend_point (
  price_trend_point_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL
    REFERENCES seafood_item(seafood_item_id) ON DELETE RESTRICT,
  location_id UUID NOT NULL
    REFERENCES location(location_id) ON DELETE RESTRICT,
  source_snapshot_id UUID NOT NULL
    REFERENCES source_snapshot(source_snapshot_id) ON DELETE RESTRICT,
  week_start DATE NOT NULL,
  weekly_median_price NUMERIC(12,2) NOT NULL,
  observation_count INTEGER NOT NULL CHECK (observation_count >= 0),
  premise_count INTEGER NOT NULL CHECK (premise_count >= 0),
  active_days SMALLINT NOT NULL CHECK (active_days >= 0),
  quality_status price_quality_enum NOT NULL,
  calculation_version TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (
    seafood_item_id,
    location_id,
    week_start,
    calculation_version
  )
);

-- =========================================================
-- 12. forecast_model_version
-- =========================================================

CREATE TABLE IF NOT EXISTS forecast_model_version (
  forecast_model_version_id UUID PRIMARY KEY,
  version_name TEXT NOT NULL UNIQUE,
  algorithm TEXT NOT NULL,
  training_window_start DATE,
  training_window_end DATE,
  validation_mae NUMERIC(12,4),
  validation_rmse NUMERIC(12,4),
  validation_mape NUMERIC(12,4),
  interval_level NUMERIC(5,4),
  configuration JSONB,
  active BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (
    interval_level IS NULL
    OR (interval_level > 0 AND interval_level < 1)
  )
);

-- =========================================================
-- 13. price_forecast  (separate from observed prices)
-- =========================================================

CREATE TABLE IF NOT EXISTS price_forecast (
  price_forecast_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL
    REFERENCES seafood_item(seafood_item_id) ON DELETE RESTRICT,
  location_id UUID NOT NULL
    REFERENCES location(location_id) ON DELETE RESTRICT,
  forecast_model_version_id UUID NOT NULL
    REFERENCES forecast_model_version(forecast_model_version_id) ON DELETE RESTRICT,
  forecast_week_start DATE NOT NULL,
  expected_price NUMERIC(12,2) NOT NULL,
  lower_bound NUMERIC(12,2) NOT NULL,
  upper_bound NUMERIC(12,2) NOT NULL,
  outlook TEXT,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (
    seafood_item_id,
    location_id,
    forecast_model_version_id,
    forecast_week_start
  ),
  CHECK (lower_bound <= expected_price AND expected_price <= upper_bound)
);

-- =========================================================
-- 14. supply_landing_point  (independent of seafood_item)
-- =========================================================

CREATE TABLE IF NOT EXISTS supply_landing_point (
  supply_landing_point_id UUID PRIMARY KEY,
  source_snapshot_id UUID NOT NULL
    REFERENCES source_snapshot(source_snapshot_id) ON DELETE RESTRICT,
  period_month DATE NOT NULL,
  scope_level TEXT NOT NULL
    CHECK (scope_level IN ('NATIONAL', 'COAST', 'COAST_STATE')),
  coast_code TEXT NOT NULL
    CHECK (coast_code IN ('all', 'east', 'west', 'borneo')),
  state_name TEXT NOT NULL,
  landings_mt NUMERIC(14,3) NOT NULL CHECK (landings_mt >= 0),
  created_at TIMESTAMPTZ NOT NULL,
  CHECK (period_month = date_trunc('month', period_month)::date),
  UNIQUE (
    source_snapshot_id,
    period_month,
    coast_code,
    state_name
  )
);

-- =========================================================
-- 15. cooking_method
-- =========================================================

CREATE TABLE IF NOT EXISTS cooking_method (
  cooking_method_id UUID PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name_en TEXT NOT NULL,
  name_ms TEXT,
  description_en TEXT
);

-- =========================================================
-- 16. cooking_suitability
-- =========================================================

CREATE TABLE IF NOT EXISTS cooking_suitability (
  cooking_suitability_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL
    REFERENCES seafood_item(seafood_item_id) ON DELETE RESTRICT,
  cooking_method_id UUID NOT NULL
    REFERENCES cooking_method(cooking_method_id) ON DELETE RESTRICT,
  source_snapshot_id UUID
    REFERENCES source_snapshot(source_snapshot_id) ON DELETE RESTRICT,
  suitability_score SMALLINT CHECK (suitability_score BETWEEN 1 AND 5),
  reason_en TEXT NOT NULL,
  reason_ms TEXT,
  updated_at TIMESTAMPTZ NOT NULL,
  UNIQUE (seafood_item_id, cooking_method_id)
);

-- =========================================================
-- 17. cv_model_version
-- =========================================================

CREATE TABLE IF NOT EXISTS cv_model_version (
  cv_model_version_id UUID PRIMARY KEY,
  version_name TEXT NOT NULL UNIQUE,
  input_contract JSONB NOT NULL,
  metrics JSONB NOT NULL,
  confidence_threshold NUMERIC(5,4),
  active BOOLEAN NOT NULL DEFAULT FALSE,
  CHECK (
    confidence_threshold IS NULL
    OR (confidence_threshold >= 0 AND confidence_threshold <= 1)
  )
);

-- =========================================================
-- 18. cv_class_mapping  (model label/index → seafood_item_id)
-- =========================================================

CREATE TABLE IF NOT EXISTS cv_class_mapping (
  cv_class_mapping_id UUID PRIMARY KEY,
  cv_model_version_id UUID NOT NULL
    REFERENCES cv_model_version(cv_model_version_id) ON DELETE RESTRICT,
  seafood_item_id UUID NOT NULL
    REFERENCES seafood_item(seafood_item_id) ON DELETE RESTRICT,
  model_class_label TEXT NOT NULL,
  model_class_index INTEGER NOT NULL,
  UNIQUE (cv_model_version_id, model_class_label)
);

-- =========================================================
-- 19. recipe
-- =========================================================

CREATE TABLE IF NOT EXISTS recipe (
  recipe_id UUID PRIMARY KEY,
  source_snapshot_id UUID NOT NULL
    REFERENCES source_snapshot(source_snapshot_id) ON DELETE RESTRICT,
  external_recipe_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  ingredients_json JSONB NOT NULL,
  instructions_json JSONB NOT NULL,
  prep_time_minutes INTEGER
    CHECK (prep_time_minutes IS NULL OR prep_time_minutes >= 0),
  cook_time_minutes INTEGER
    CHECK (cook_time_minutes IS NULL OR cook_time_minutes >= 0),
  total_time_minutes INTEGER
    CHECK (total_time_minutes IS NULL OR total_time_minutes >= 0),
  servings NUMERIC(8,2)
    CHECK (servings IS NULL OR servings > 0),
  cuisine TEXT,
  nutrition_json JSONB,
  source_url TEXT,
  created_at TIMESTAMPTZ NOT NULL
);

-- =========================================================
-- 20. recipe_seafood_mapping
-- =========================================================

CREATE TABLE IF NOT EXISTS recipe_seafood_mapping (
  recipe_seafood_mapping_id UUID PRIMARY KEY,
  recipe_id UUID NOT NULL
    REFERENCES recipe(recipe_id) ON DELETE RESTRICT,
  seafood_item_id UUID NOT NULL
    REFERENCES seafood_item(seafood_item_id) ON DELETE RESTRICT,
  mapping_type recipe_mapping_type_enum NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  UNIQUE (recipe_id, seafood_item_id)
);

-- =========================================================
-- 21. recipe_cooking_method
-- =========================================================

CREATE TABLE IF NOT EXISTS recipe_cooking_method (
  recipe_cooking_method_id UUID PRIMARY KEY,
  recipe_id UUID NOT NULL
    REFERENCES recipe(recipe_id) ON DELETE RESTRICT,
  cooking_method_id UUID NOT NULL
    REFERENCES cooking_method(cooking_method_id) ON DELETE RESTRICT,
  source_method_text TEXT,
  notes TEXT,
  UNIQUE (recipe_id, cooking_method_id)
);

COMMIT;
