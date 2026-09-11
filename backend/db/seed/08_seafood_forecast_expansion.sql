-- =========================================================
-- 08_seafood_forecast_expansion.sql
-- =========================================================
-- Canonical rows for the two species the price-forecast engine forecasts that
-- no earlier seed created, plus the data_source and source_snapshot the
-- forecast rows hang off.
--
-- Why these two species exist here and not in 04 or 05:
--   04 froze the five I1 species. 05 added the seven the image corpus covers,
--   because the scanner can only name what it has images for. The forecasting
--   engine has a third, overlapping scope: the twelve fish with enough recent
--   PriceCatcher history to forecast. Ten of those already have canonical
--   rows. These two do not, and Step 33B requires every forecast row to
--   resolve to a seafood_item_id rather than carry a display name as its key.
--
--   Both get supports_cv = FALSE. The trained class map has nine classes and
--   neither of these is among them; claiming otherwise would let /identify
--   offer a species the model was never taught.
--
-- Idempotent: safe to re-run.
-- Requires: schema/v3_functions_indexes.sql, 02_data_sources.sql

BEGIN;

-- =========================================================
-- seafood_item — the two forecast-only additions
-- =========================================================
INSERT INTO seafood_item (
  seafood_item_id, code, canonical_name_ms, display_name_en,
  scientific_name, scientific_name_normalized, taxonomic_level, family,
  fish_type, description, supports_cv, active, notes
)
SELECT
  suka_uuid5('seafood_item:' || v.code),
  v.code, v.canonical_name_ms, v.display_name_en,
  v.scientific_name, lower(trim(v.scientific_name)), v.taxonomic_level, v.family,
  v.fish_type, v.description, v.supports_cv, TRUE, v.notes
FROM (VALUES
  -- Recorded at family level because that is as far as the evidence goes. The
  -- project mapping lists this row as "Ponyfish" with no species named, and
  -- inventing a binomial to fill the column would be a fabricated fact.
  ('SF013', 'Demuduk / Cupak / Cermin', 'Ponyfish', 'Leiognathidae spp.',
   'family', 'Leiognathidae', 'marine demersal',
   'Small silvery ponyfish sold cheaply by the heap under several regional names. Usually fried whole or salted; a budget staple rather than a centrepiece fish.',
   FALSE,
   'Family-level record: the project mapping names no species, and the public WWF guide does not expose this listing. PriceCatcher item 1916.'),

  ('SF014', 'Siakap Putih', 'Asian Seabass', 'Lates calcarifer',
   'species', 'Latidae', 'coastal / farmed',
   'Barramundi, farmed and wild-caught, and the default restaurant steamed fish. Year-round farming keeps its price steadier than most wild species.',
   FALSE,
   'PriceCatcher lists this as "Siakap"; WWF uses "Siakap Putih". The WWF name is canonical here so the sustainability and price journeys agree.')
) AS v(code, canonical_name_ms, display_name_en, scientific_name,
       taxonomic_level, family, fish_type, description, supports_cv, notes)
ON CONFLICT (seafood_item_id) DO UPDATE SET
  code                         = EXCLUDED.code,
  canonical_name_ms            = EXCLUDED.canonical_name_ms,
  display_name_en              = EXCLUDED.display_name_en,
  scientific_name              = EXCLUDED.scientific_name,
  scientific_name_normalized   = EXCLUDED.scientific_name_normalized,
  taxonomic_level              = EXCLUDED.taxonomic_level,
  family                       = EXCLUDED.family,
  fish_type                    = EXCLUDED.fish_type,
  description                  = EXCLUDED.description,
  supports_cv                  = EXCLUDED.supports_cv,
  active                       = EXCLUDED.active,
  notes                        = EXCLUDED.notes,
  updated_at                   = now();

-- =========================================================
-- seafood_alias — search must reach them
-- =========================================================
INSERT INTO seafood_alias (
  seafood_alias_id, seafood_item_id, alias_name, language_code, alias_type, verified
)
SELECT
  suka_uuid5('seafood_alias:' || v.code || ':' || lower(trim(v.alias_name))),
  suka_uuid5('seafood_item:' || v.code),
  v.alias_name, v.language_code, v.alias_type::seafood_alias_type_enum, v.verified
FROM (VALUES
  -- SF013 — all three market names, since no single one dominates
  ('SF013', 'Demuduk',            'ms', 'MALAY',          TRUE),
  ('SF013', 'Cupak',              'ms', 'MARKET',         TRUE),
  ('SF013', 'Cermin',             'ms', 'MARKET',         TRUE),
  ('SF013', 'Ikan Cermin',        'ms', 'MARKET',         FALSE),
  ('SF013', 'Ponyfish',           'en', 'ENGLISH_COMMON', TRUE),
  ('SF013', 'Leiognathidae',      'la', 'SCIENTIFIC',     TRUE),

  -- SF014
  ('SF014', 'Siakap Putih',       'ms', 'MALAY',          TRUE),
  ('SF014', 'Siakap',             'ms', 'MARKET',         TRUE),
  ('SF014', 'Ikan Siakap',        'ms', 'MALAY',          TRUE),
  ('SF014', 'Asian Seabass',      'en', 'ENGLISH_COMMON', TRUE),
  ('SF014', 'Barramundi',         'en', 'ENGLISH_COMMON', TRUE),
  ('SF014', 'Lates calcarifer',   'la', 'SCIENTIFIC',     TRUE)
) AS v(code, alias_name, language_code, alias_type, verified)
ON CONFLICT (seafood_alias_id) DO UPDATE SET
  alias_name    = EXCLUDED.alias_name,
  language_code = EXCLUDED.language_code,
  alias_type    = EXCLUDED.alias_type,
  verified      = EXCLUDED.verified;

-- =========================================================
-- data_source + source_snapshot for the forecasting engine
-- =========================================================
-- The engine is a distinct publisher from PriceCatcher. It consumes
-- PriceCatcher observations and emits a modelled outlook, and the app must be
-- able to tell a shopper which of those two a number came from — an observed
-- price and a forecast carry very different authority.
INSERT INTO data_source (data_source_id, source_key, name, owner, type, homepage_url, license, active)
SELECT
  suka_uuid5('data_source:' || v.source_key),
  v.source_key, v.name, v.owner, v.type, v.homepage_url, v.license, TRUE
FROM (VALUES
  ('suka_forecast_engine',
   'SukaSeafood Price Forecast Engine',
   'SukaSeafood project team (R forecasting pipeline)',
   'FORECAST',
   NULL,
   'Internal model output derived from OpenDOSM PriceCatcher. A range-based outlook, not an official or guaranteed price.')
) AS v(source_key, name, owner, type, homepage_url, license)
ON CONFLICT (data_source_id) DO UPDATE SET
  source_key   = EXCLUDED.source_key,
  name         = EXCLUDED.name,
  owner        = EXCLUDED.owner,
  type         = EXCLUDED.type,
  homepage_url = EXCLUDED.homepage_url,
  license      = EXCLUDED.license,
  active       = EXCLUDED.active;

-- One snapshot per production forecast run. The manifest records which
-- PriceCatcher extract fed the run and which R scripts produced it, which is
-- what makes a displayed forecast auditable back to its inputs.
INSERT INTO source_snapshot (
  source_snapshot_id, data_source_id, version_label,
  source_period_start, source_period_end, retrieved_at, collection_method, manifest, notes
)
SELECT
  suka_uuid5('source_snapshot:' || v.source_key || ':' || v.version_label),
  suka_uuid5('data_source:' || v.source_key),
  v.version_label,
  v.period_start::date,
  v.period_end::date,
  v.retrieved_at::timestamptz,
  v.collection_method::collection_method_enum,
  v.manifest::jsonb,
  v.notes
FROM (VALUES
  ('suka_forecast_engine', 'forecast-2026-08-v1', '2025-01-06', '2026-08-17',
   '2026-08-30T22:48:38+00:00', 'MODEL_ARTIFACT',
   '{"upstream_source": "opendosm_pricecatcher", "outputs": ["db_price_forecast_staging.csv", "db_forecast_model_version_staging.csv"], "scripts": ["R_29.1_final_forecast_eligibility.R", "R_31_direction_outlook_validation.R", "R_32_integrate_production_forecast.R", "R_33A_create_database_forecast_staging.R"], "location_scope": "Selangor", "horizon_weeks": 4}',
   'Production forecast run of 2026-08-30. source_period covers the modelling window; the last completed PriceCatcher week was 2026-08-17.')
) AS v(source_key, version_label, period_start, period_end, retrieved_at, collection_method, manifest, notes)
ON CONFLICT (source_snapshot_id) DO UPDATE SET
  source_period_start = EXCLUDED.source_period_start,
  source_period_end   = EXCLUDED.source_period_end,
  retrieved_at        = EXCLUDED.retrieved_at,
  collection_method   = EXCLUDED.collection_method,
  manifest            = EXCLUDED.manifest,
  notes               = EXCLUDED.notes;

-- =========================================================
-- Guard rails
-- =========================================================
DO $$
DECLARE
  n_cv INT;
BEGIN
  -- The five-class scanner contract must survive this file.
  SELECT count(*) INTO n_cv FROM seafood_item WHERE supports_cv;
  IF n_cv <> 5 THEN
    RAISE EXCEPTION 'expected 5 CV-supported species after the forecast expansion, found %', n_cv;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM seafood_item WHERE code = 'SF013')
  OR NOT EXISTS (SELECT 1 FROM seafood_item WHERE code = 'SF014') THEN
    RAISE EXCEPTION 'SF013/SF014 missing — forecast rows for two fish would have no canonical key';
  END IF;
END $$;

COMMIT;
