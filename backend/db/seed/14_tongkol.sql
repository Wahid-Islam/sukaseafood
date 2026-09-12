-- Tongkol is on the Popular in Malaysia list. It was not in the I1/I2
-- fourteen-species hub. WWF and PriceCatcher rows are intentionally absent.

BEGIN;

INSERT INTO seafood_item (
  seafood_item_id, code, canonical_name_ms, display_name_en,
  scientific_name, scientific_name_normalized, taxonomic_level, family,
  fish_type, description, supports_cv, active, notes, primary_image_url
)
SELECT
  suka_uuid5('seafood_item:SF015'),
  'SF015',
  'Tongkol',
  'Kawakawa / Longtail Tuna',
  'Euthynnus affinis',
  'euthynnus affinis',
  'species',
  'Scombridae',
  'marine pelagic',
  'A versatile tuna commonly used in curries and other dishes.',
  FALSE,
  TRUE,
  'Added for Discovery Popular in Malaysia. No WWF assessment or PriceCatcher mapping is on file.',
  'https://commons.wikimedia.org/wiki/Special:FilePath/Euthynnus_affinis.jpg?width=800'
WHERE NOT EXISTS (SELECT 1 FROM seafood_item WHERE code = 'SF015');

INSERT INTO seafood_alias (
  seafood_alias_id, seafood_item_id, alias_name, language_code, alias_type, verified
)
SELECT
  suka_uuid5('seafood_alias:SF015:' || v.alias_name),
  suka_uuid5('seafood_item:SF015'),
  v.alias_name, v.language_code, v.alias_type::seafood_alias_type_enum, TRUE
FROM (VALUES
  ('Tongkol', 'ms', 'MALAY'),
  ('Ikan Tongkol', 'ms', 'MALAY'),
  ('Kawakawa', 'en', 'ENGLISH_COMMON'),
  ('Longtail Tuna', 'en', 'ENGLISH_COMMON'),
  ('Euthynnus affinis', 'la', 'SCIENTIFIC')
) AS v(alias_name, language_code, alias_type)
ON CONFLICT DO NOTHING;

INSERT INTO cooking_suitability (
  cooking_suitability_id, seafood_item_id, cooking_method_id, source_snapshot_id,
  suitability_score, reason_en, reason_ms, updated_at
)
SELECT
  suka_uuid5('cooking_suitability:SF015:' || v.method),
  suka_uuid5('seafood_item:SF015'),
  suka_uuid5('cooking_method:' || v.method),
  suka_uuid5('source_snapshot:team_curated:curation-i1'),
  v.score::smallint,
  v.reason_en,
  v.reason_ms,
  TIMESTAMPTZ '2026-09-12 00:00:00+08'
FROM (VALUES
  ('CURRY', 5, 'Firm steaks hold in a long-simmered curry.', 'Kepingan padat tahan dalam kari yang dimasak lama.'),
  ('GRILL', 4, 'Oily flesh takes direct heat without falling apart.', 'Isi berminyak tahan dipanggang tanpa hancur.'),
  ('FRY', 4, 'Cutlets fry evenly in a shallow pan.', 'Potongan mudah digoreng sekata.')
) AS v(method, score, reason_en, reason_ms)
ON CONFLICT (cooking_suitability_id) DO UPDATE SET
  suitability_score = EXCLUDED.suitability_score,
  reason_en = EXCLUDED.reason_en,
  reason_ms = EXCLUDED.reason_ms;

COMMIT;
