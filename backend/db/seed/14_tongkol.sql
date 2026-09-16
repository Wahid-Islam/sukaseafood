-- Cooking scores already on file for SF015 Tongkol (Thunnus tonggol).
-- The canonical row and WWF listing live in 10_wwf_catalogue_54.sql.

BEGIN;

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
