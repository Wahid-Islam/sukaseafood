-- SukaSeafood Iteration 1
-- PostgreSQL schema — DDL only (17 tables, 8 enums).
--
-- Source of truth for the I1 "Database & Data Structure Design" handoff.
-- Runs against a fresh/empty schema on PostgreSQL 14+ (local Docker or Supabase).
--
-- This file creates STRUCTURE ONLY. Reference and canonical data live in
-- ../seed/*.sql and are applied after this file, in filename order:
--
--   1. schema/i1_initial_schema.sql     <- this file (tables, enums, indexes)
--   2. schema/i1_functions_indexes.sql  <- suka_uuid5() + operational constraints
--   3. seed/01_locations.sql            <- Malaysian states + districts
--   4. seed/02_data_sources.sql         <- data_source + source_snapshot
--   5. seed/03_cooking_methods.sql      <- cooking_method vocabulary
--   6. seed/04_seafood_i1.sql           <- the 5 I1 species + aliases
--
-- Apply everything at once with:  backend/db/apply.sh
--
-- I1 originally shipped anonymous (no auth tables). App accounts now live in
-- schema/i1_app_user.sql (PostgreSQL only — not Firestore).
-- Business rules (WWF clarification, PriceCatcher fallback)
-- live in FastAPI, not in database triggers.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
    ('EXACT', 'COMMON_NAME', 'MARKET_VARIANT', 'MARKET_GROUP');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE price_quality_enum AS ENUM
    ('DISPLAYABLE', 'INSUFFICIENT_DATA', 'REJECTED');
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
  parent_location_id UUID REFERENCES location(location_id),
  level location_level_enum NOT NULL,
  state_name TEXT NOT NULL,
  district_name TEXT,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

-- =========================================================
-- 2. seafood_item
-- =========================================================

CREATE TABLE IF NOT EXISTS seafood_item (
  seafood_item_id UUID PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  canonical_name_ms TEXT NOT NULL,
  display_name_en TEXT NOT NULL,
  scientific_name TEXT NOT NULL UNIQUE,
  family TEXT,
  supports_cv BOOLEAN NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  notes TEXT
);

-- =========================================================
-- 3. seafood_alias
-- =========================================================

CREATE TABLE IF NOT EXISTS seafood_alias (
  seafood_alias_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL REFERENCES seafood_item(seafood_item_id),
  alias_name TEXT NOT NULL,
  language_code TEXT,
  alias_type seafood_alias_type_enum NOT NULL,
  verified BOOLEAN NOT NULL
);

-- Search index requested by the final design.
CREATE INDEX IF NOT EXISTS idx_seafood_alias_search
  ON seafood_alias (LOWER(TRIM(alias_name)));

-- Keep aliases unique per seafood using the same normalised search expression.
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
  data_source_id UUID NOT NULL REFERENCES data_source(data_source_id),
  version_label TEXT NOT NULL,
  source_period_start DATE,
  source_period_end DATE,
  retrieved_at TIMESTAMPTZ NOT NULL,
  collection_method collection_method_enum NOT NULL,
  manifest JSONB,
  notes TEXT
);

-- =========================================================
-- 6. wwf_assessment
-- =========================================================

CREATE TABLE IF NOT EXISTS wwf_assessment (
  wwf_assessment_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL REFERENCES seafood_item(seafood_item_id),
  source_snapshot_id UUID NOT NULL REFERENCES source_snapshot(source_snapshot_id),
  source_record_key TEXT NOT NULL, 
  seafood_category TEXT,           
  main_common_name TEXT NOT NULL,  
  secondary_common_name TEXT,      
  scientific_name TEXT NOT NULL,   
  sustainability_rating sustainability_rating_enum NOT NULL, 
  origin TEXT,                   
  production_method_raw TEXT,      
  certification_raw TEXT,          
  alternatives TEXT,            
  source_pdf_page INT,          
  canonical_fish_id TEXT,      
  fish_type TEXT,                 
  description TEXT,                
  context TEXT,                    
  notes_raw TEXT                
);


-- =========================================================
-- 7. pricecatcher_item
-- =========================================================

CREATE TABLE IF NOT EXISTS pricecatcher_item (
  pricecatcher_item_id UUID PRIMARY KEY,
  source_snapshot_id UUID NOT NULL REFERENCES source_snapshot(source_snapshot_id),
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
-- 8. price_item_mapping
-- =========================================================

CREATE TABLE IF NOT EXISTS price_item_mapping (
  price_item_mapping_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL REFERENCES seafood_item(seafood_item_id),
  pricecatcher_item_id UUID NOT NULL REFERENCES pricecatcher_item(pricecatcher_item_id),
  mapping_type price_mapping_type_enum NOT NULL,
  priority SMALLINT NOT NULL CHECK (priority > 0),
  is_default_for_generic BOOLEAN NOT NULL,
  requires_variant_confirmation BOOLEAN NOT NULL,
  notes TEXT,
  UNIQUE (seafood_item_id, pricecatcher_item_id)
);

-- =========================================================
-- 9. price_summary
-- =========================================================

CREATE TABLE IF NOT EXISTS price_summary (
  price_summary_id UUID PRIMARY KEY,
  pricecatcher_item_id UUID NOT NULL REFERENCES pricecatcher_item(pricecatcher_item_id),
  location_id UUID NOT NULL REFERENCES location(location_id),
  source_snapshot_id UUID NOT NULL REFERENCES source_snapshot(source_snapshot_id),
  location_level location_level_enum NOT NULL,
  window_days SMALLINT NOT NULL CHECK (window_days IN (30, 90)),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  median_price NUMERIC(12,2) NOT NULL,
  p25_price NUMERIC(12,2),
  p75_price NUMERIC(12,2),
  observation_count INTEGER NOT NULL CHECK (observation_count >= 0),
  premise_count INTEGER NOT NULL CHECK (premise_count >= 0),
  distinct_day_count INTEGER NOT NULL CHECK (distinct_day_count >= 0),
  quality_status price_quality_enum NOT NULL,
  calculation_version TEXT NOT NULL,
  calculated_at TIMESTAMPTZ NOT NULL,
  UNIQUE (
    pricecatcher_item_id,
    location_id,
    window_days,
    period_end,
    calculation_version
  )
);

-- =========================================================
-- 10. price_trend_point
-- =========================================================

CREATE TABLE IF NOT EXISTS price_trend_point (
  price_trend_point_id UUID PRIMARY KEY,
  pricecatcher_item_id UUID NOT NULL REFERENCES pricecatcher_item(pricecatcher_item_id),
  location_id UUID NOT NULL REFERENCES location(location_id),
  source_snapshot_id UUID NOT NULL REFERENCES source_snapshot(source_snapshot_id),
  location_level location_level_enum NOT NULL,
  week_start DATE NOT NULL,
  weekly_median NUMERIC(12,2) NOT NULL,
  observation_count INTEGER NOT NULL CHECK (observation_count >= 0),
  premise_count INTEGER NOT NULL CHECK (premise_count >= 0),
  quality_status price_quality_enum NOT NULL,
  calculation_version TEXT NOT NULL,
  UNIQUE (
    pricecatcher_item_id,
    location_id,
    week_start,
    calculation_version
  )
);

-- =========================================================
-- 11. supply_landing_point
-- =========================================================

CREATE TABLE IF NOT EXISTS supply_landing_point (
  supply_landing_point_id UUID PRIMARY KEY,
  source_snapshot_id UUID NOT NULL REFERENCES source_snapshot(source_snapshot_id),
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
-- 12. cooking_method
-- =========================================================

CREATE TABLE IF NOT EXISTS cooking_method (
  cooking_method_id UUID PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name_en TEXT NOT NULL,
  name_ms TEXT,
  description_en TEXT
);

-- =========================================================
-- 13. cooking_suitability
-- =========================================================

CREATE TABLE IF NOT EXISTS cooking_suitability (
  cooking_suitability_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL REFERENCES seafood_item(seafood_item_id),
  cooking_method_id UUID NOT NULL REFERENCES cooking_method(cooking_method_id),
  source_snapshot_id UUID REFERENCES source_snapshot(source_snapshot_id),
  suitability_score SMALLINT CHECK (suitability_score BETWEEN 1 AND 5),
  reason_en TEXT NOT NULL,
  reason_ms TEXT,
  updated_at TIMESTAMPTZ NOT NULL,
  UNIQUE (seafood_item_id, cooking_method_id)
);

-- =========================================================
-- 14. cv_model_version
-- =========================================================

CREATE TABLE IF NOT EXISTS cv_model_version (
  cv_model_version_id UUID PRIMARY KEY,
  version_name TEXT NOT NULL UNIQUE,
  input_contract JSONB NOT NULL,
  metrics JSONB NOT NULL,
  confidence_threshold NUMERIC(5,4),
  CHECK (
    confidence_threshold IS NULL
    OR (confidence_threshold >= 0 AND confidence_threshold <= 1)
  )
);

-- =========================================================
-- 15. recipe
-- =========================================================

CREATE TABLE IF NOT EXISTS recipe (
  recipe_id UUID PRIMARY KEY,
  source_snapshot_id UUID NOT NULL REFERENCES source_snapshot(source_snapshot_id),
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
-- 16. recipe_seafood_mapping
-- =========================================================

CREATE TABLE IF NOT EXISTS recipe_seafood_mapping (
  recipe_seafood_mapping_id UUID PRIMARY KEY,
  recipe_id UUID NOT NULL REFERENCES recipe(recipe_id),
  seafood_item_id UUID NOT NULL REFERENCES seafood_item(seafood_item_id),
  mapping_type recipe_mapping_type_enum NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  UNIQUE (recipe_id, seafood_item_id)
);

-- =========================================================
-- 17. recipe_cooking_method
-- =========================================================

CREATE TABLE IF NOT EXISTS recipe_cooking_method (
  recipe_cooking_method_id UUID PRIMARY KEY,
  recipe_id UUID NOT NULL REFERENCES recipe(recipe_id),
  cooking_method_id UUID NOT NULL REFERENCES cooking_method(cooking_method_id),
  source_method_text TEXT,
  notes TEXT,
  UNIQUE (recipe_id, cooking_method_id)
);

COMMIT;
