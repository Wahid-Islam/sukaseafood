-- SukaSeafood I1 — reference seed 02: data_source + source_snapshot
--
-- Every fact the app displays must be traceable to a source snapshot. The
-- GET /sources endpoint and the "where did this number come from" line in the
-- UI both read from these two tables.
--
-- A data_source is the publisher. A source_snapshot is one dated extract from
-- that publisher: it is what wwf_assessment, pricecatcher_item, price_period_summary,
-- supply_landing_point and recipe all hang off, so re-importing a newer extract
-- never silently overwrites the evidence behind what a user already saw.
--
-- Idempotent: safe to re-run.
-- Requires: schema/i1_functions_indexes.sql

BEGIN;

INSERT INTO data_source (data_source_id, source_key, name, owner, type, homepage_url, license, active)
SELECT
  suka_uuid5('data_source:' || v.source_key),
  v.source_key, v.name, v.owner, v.type, v.homepage_url, v.license, TRUE
FROM (VALUES
  ('wwf_sos',
   'WWF Save Our Seafood',
   'WWF-Malaysia',
   'SUSTAINABILITY',
   'https://www.saveourseafood.my/',
   'WWF-Malaysia consumer guide. Cite WWF SOS; verify the listing before any public claim.'),

  ('opendosm_pricecatcher',
   'OpenDOSM PriceCatcher',
   'Department of Statistics Malaysia',
   'PRICE',
   'https://open.dosm.gov.my/data-catalogue/pricecatcher',
   'Open data (data.gov.my terms). Observed premise prices — NOT a nationally representative average.'),

  ('opendosm_fish_landings',
   'OpenDOSM Fish Landings',
   'Department of Statistics Malaysia',
   'SUPPLY',
   'https://open.dosm.gov.my/data-catalogue/fish_landings',
   'Open data (data.gov.my terms). Aggregate landings context only — not species-level forecasting.'),

  ('team_curated',
   'SukaSeafood Team Curation',
   'SukaSeafood project team',
   'CURATED',
   NULL,
   'Internal editorial content (cooking suitability, copy). Reviewed by the team, not an external authority.'),

  ('fish_vista',
   'Fish-Vista (Imageomics)',
   'Imageomics Institute',
   'CV_MODEL',
   'https://github.com/sajeedmehrab/Fish-Vista',
   'Cite Fish-Vista and the original museum image sources.')
) AS v(source_key, name, owner, type, homepage_url, license)
ON CONFLICT (data_source_id) DO UPDATE SET
  source_key   = EXCLUDED.source_key,
  name         = EXCLUDED.name,
  owner        = EXCLUDED.owner,
  type         = EXCLUDED.type,
  homepage_url = EXCLUDED.homepage_url,
  license      = EXCLUDED.license,
  active       = EXCLUDED.active;

-- Baseline snapshots for the extracts shipped with the I1 developer handoff.
-- The ETL replaces these version_labels as newer extracts land; it must never
-- mutate a snapshot that already has rows pointing at it.
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
  ('wwf_sos', 'wwf-sos-2026-handoff', NULL, NULL,
   '2026-08-01T00:00:00+08:00', 'MANUAL_PDF_TRANSCRIPTION',
   '{"files": ["WWF-sustainability.pdf"]}',
   'Transcribed by hand from the WWF SOS consumer guide PDF. Every row needs a human check before display.'),

  ('opendosm_pricecatcher', 'pricecatcher-2026-06--2026-08', '2026-06-01', '2026-08-31',
   '2026-08-01T00:00:00+08:00', 'OFFICIAL_DOWNLOAD',
   '{"files": ["pricecatcher_2026-06.csv", "pricecatcher_2026-07.csv", "pricecatcher_2026-08.csv", "pricecatcher_lookup_item.csv", "pricecatcher_lookup_premise.csv"]}',
   'Three months of premise-level observations. Supports the 30d and 90d summary windows and the 12-week trend.'),

  ('opendosm_fish_landings', 'fish-landings-2018--2026', '2018-01-01', '2026-08-31',
   '2026-08-01T00:00:00+08:00', 'OFFICIAL_DOWNLOAD',
   '{"files": ["fish_landings.csv"]}',
   'Monthly landings by coast and state. Supply CONTEXT only — never presented as a species-level prediction.'),

  ('team_curated', 'curation-i1', NULL, NULL,
   '2026-08-01T00:00:00+08:00', 'TEAM_CURATED',
   '{"scope": ["cooking_method", "cooking_suitability"]}',
   'I1 editorial baseline for cooking recommendations.'),

  ('fish_vista', 'fish-vista-i1-mock', NULL, NULL,
   '2026-08-01T00:00:00+08:00', 'MODEL_ARTIFACT',
   '{"files": ["FishVista-classification_train.csv", "FishVista-classification_val.csv", "FishVista-classification_test.csv"]}',
   'Placeholder snapshot for the mock CV adapter. Swap when a real trained model ships.')
) AS v(source_key, version_label, period_start, period_end, retrieved_at, collection_method, manifest, notes)
ON CONFLICT (source_snapshot_id) DO UPDATE SET
  source_period_start = EXCLUDED.source_period_start,
  source_period_end   = EXCLUDED.source_period_end,
  retrieved_at        = EXCLUDED.retrieved_at,
  collection_method   = EXCLUDED.collection_method,
  manifest            = EXCLUDED.manifest,
  notes               = EXCLUDED.notes;

COMMIT;
