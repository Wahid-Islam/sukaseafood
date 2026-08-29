-- Migrate an existing I1 database to V3.
--
-- Safe to run after v3_initial_schema.sql on a fresh DB (no-ops where
-- structures already match). Designed for Cloud SQL / local Docker that
-- already applied the I1 handoff DDL.
--
-- Key V3 changes:
--   * seafood_item gains taxonomic/presentation fields
--   * price_summary → price_period_summary keyed by seafood_item_id
--   * price_trend_point re-keyed by seafood_item_id
--   * pricecatcher_premise, forecast_*, cv_class_mapping added
--   * price_item_mapping gains aggregation_rule + mapping_confidence

BEGIN;

-- ---------------------------------------------------------
-- Enums (create if missing; PROXY on mapping type)
-- ---------------------------------------------------------

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
  CREATE TYPE period_type_enum AS ENUM
    ('WEEK', 'MONTH', 'QUARTER');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TYPE price_mapping_type_enum ADD VALUE IF NOT EXISTS 'PROXY';
EXCEPTION WHEN others THEN NULL;
END $$;

-- ---------------------------------------------------------
-- seafood_item column upgrades
-- ---------------------------------------------------------

ALTER TABLE seafood_item
  ADD COLUMN IF NOT EXISTS scientific_name_normalized TEXT,
  ADD COLUMN IF NOT EXISTS taxonomic_level TEXT,
  ADD COLUMN IF NOT EXISTS fish_type TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS primary_image_url TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

UPDATE seafood_item
SET scientific_name_normalized = lower(trim(scientific_name))
WHERE scientific_name_normalized IS NULL;

UPDATE seafood_item
SET taxonomic_level = 'species'
WHERE taxonomic_level IS NULL;

UPDATE seafood_item SET fish_type = CASE family
  WHEN 'Scombridae' THEN 'marine pelagic'
  WHEN 'Carangidae' THEN 'marine demersal'
  WHEN 'Lutjanidae' THEN 'marine demersal'
  WHEN 'Serranidae' THEN 'marine demersal'
  WHEN 'Cichlidae'  THEN 'freshwater'
  ELSE COALESCE(family, 'seafood')
END
WHERE fish_type IS NULL;

UPDATE seafood_item
SET description = COALESCE(notes, display_name_en)
WHERE description IS NULL;

UPDATE seafood_item
SET created_at = now()
WHERE created_at IS NULL;

UPDATE seafood_item
SET updated_at = now()
WHERE updated_at IS NULL;

ALTER TABLE seafood_item
  ALTER COLUMN taxonomic_level SET NOT NULL,
  ALTER COLUMN fish_type SET NOT NULL,
  ALTER COLUMN description SET NOT NULL,
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN updated_at SET DEFAULT now(),
  ALTER COLUMN created_at SET NOT NULL,
  ALTER COLUMN updated_at SET NOT NULL;

-- Drop I1 UNIQUE on scientific_name if present (V3 indexes normalized form).
DO $$ BEGIN
  ALTER TABLE seafood_item DROP CONSTRAINT IF EXISTS seafood_item_scientific_name_key;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

-- ---------------------------------------------------------
-- wwf_assessment column upgrades
-- ---------------------------------------------------------

ALTER TABLE wwf_assessment
  ADD COLUMN IF NOT EXISTS secondary_common_name_raw TEXT,
  ADD COLUMN IF NOT EXISTS context TEXT;

-- Replace I1 natural uniqueness with V3 scoped uniqueness.
DROP INDEX IF EXISTS uq_wwf_assessment_natural;

DO $$ BEGIN
  ALTER TABLE wwf_assessment
    ADD CONSTRAINT wwf_assessment_source_snapshot_id_source_record_key_key
    UNIQUE (source_snapshot_id, source_record_key);
EXCEPTION WHEN duplicate_object OR duplicate_table THEN NULL;
END $$;

-- ---------------------------------------------------------
-- price_item_mapping column upgrades
-- ---------------------------------------------------------

ALTER TABLE price_item_mapping
  ADD COLUMN IF NOT EXISTS aggregation_rule aggregation_rule_enum,
  ADD COLUMN IF NOT EXISTS mapping_confidence mapping_confidence_enum;

UPDATE price_item_mapping
SET aggregation_rule = 'SEPARATE'
WHERE aggregation_rule IS NULL;

UPDATE price_item_mapping
SET mapping_confidence = 'MEDIUM'
WHERE mapping_confidence IS NULL;

ALTER TABLE price_item_mapping
  ALTER COLUMN aggregation_rule SET DEFAULT 'SEPARATE',
  ALTER COLUMN aggregation_rule SET NOT NULL,
  ALTER COLUMN mapping_confidence SET DEFAULT 'MEDIUM',
  ALTER COLUMN mapping_confidence SET NOT NULL;

-- ---------------------------------------------------------
-- New tables created by v3_initial_schema.sql (IF NOT EXISTS)
-- Drop I1 price_summary after period summary exists.
-- ---------------------------------------------------------

-- Recreate price_trend_point if still on I1 shape (pricecatcher_item_id).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'price_trend_point'
      AND column_name = 'pricecatcher_item_id'
  ) THEN
    -- Empty by design until ETL; safe to rebuild.
    DROP TABLE price_trend_point CASCADE;

    CREATE TABLE price_trend_point (
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
  END IF;
END $$;

-- Drop I1 price_summary once price_period_summary exists.
DROP TABLE IF EXISTS price_summary CASCADE;

-- cv_model_version.active
ALTER TABLE cv_model_version
  ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT FALSE;

COMMIT;
