-- SukaSeafood I1 — reference seed 03: cooking_method
--
-- The controlled vocabulary behind GET /cooking/{method}. Codes are stable and
-- lowercase-safe: the API accepts 'grill' or 'GRILL' and resolves on code.
--
-- Malay names are included because the app is bilingual and the cooking screen
-- is the surface most likely to be read in Malay.
--
-- Idempotent: safe to re-run.
-- Requires: schema/i1_functions_indexes.sql

BEGIN;

INSERT INTO cooking_method (cooking_method_id, code, name_en, name_ms, description_en)
SELECT suka_uuid5('cooking_method:' || v.code), v.code, v.name_en, v.name_ms, v.description_en
FROM (VALUES
  ('GRILL', 'Grill',      'Panggang',
   'Direct dry heat over flame or coals. Suits firm, oily fish that hold together on a grate.'),
  ('STEAM', 'Steam',      'Kukus',
   'Gentle moist heat. Suits delicate white-fleshed fish where freshness is the selling point.'),
  ('FRY',   'Fry',        'Goreng',
   'Shallow or deep frying. Suits smaller whole fish and firm cuts that crisp well.'),
  ('CURRY', 'Curry',      'Kari / Masak Lemak',
   'Simmered in a spiced or coconut gravy. Suits fish firm enough not to break up in liquid.'),
  ('SOUP',  'Soup',       'Sup / Masak Air',
   'Clear or light broth. Suits fish with bones and heads that give body to the stock.'),
  ('BAKE',  'Bake',       'Bakar dalam Ketuhar',
   'Enclosed oven heat, often wrapped. Suits whole fish and thicker fillets.'),
  ('RAW',   'Raw / Cured', 'Mentah / Jeruk',
   'Served raw or acid-cured. Requires sashimi-grade handling — flagged, not recommended by default in I1.')
) AS v(code, name_en, name_ms, description_en)
ON CONFLICT (cooking_method_id) DO UPDATE SET
  code           = EXCLUDED.code,
  name_en        = EXCLUDED.name_en,
  name_ms        = EXCLUDED.name_ms,
  description_en = EXCLUDED.description_en;

COMMIT;
