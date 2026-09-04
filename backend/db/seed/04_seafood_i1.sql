-- SukaSeafood I1 — canonical seed 04: the five supported species
--
-- seafood_item is the hub of the whole domain: search, CV identify, WWF rating,
-- price and cooking all resolve to one seafood_item_id. Everything else in the
-- schema is an attachment to a row in this table.
--
-- Deliberate omissions (they are not gaps):
--   * Kerapu Bintik gets NO wwf_assessment row. WWF SOS guidance is ambiguous
--     across grouper species and production methods, so the API returns
--     UNDETERMINED. sustainability_rating_enum has no UNDETERMINED member by
--     design — "we don't know" is the absence of an assessment, never a rating.
--   * primary_image_url is optional. When null, the API falls back to Firebase
--     Storage paths derived from `code` (see backend/app/firebase.py).
--
-- Idempotent: safe to re-run.
-- Requires: schema/v3_functions_indexes.sql, seed/02_data_sources.sql,
--           seed/03_cooking_methods.sql

BEGIN;

-- =========================================================
-- seafood_item
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
  ('SF001', 'Kembung / Pelaling', 'Indian Mackerel', 'Rastrelliger kanagurta',
   'species', 'Scombridae', 'marine pelagic',
   'Small pelagic sold in almost every Malaysian wet market and supermarket. Cheap, oily, and the default everyday fish — which makes it the most useful comparison point when a shopper is deciding between species.',
   TRUE,
   'Small pelagic sold in almost every Malaysian wet market and supermarket. Cheap, oily, and the default everyday fish — which makes it the most useful comparison point when a shopper is deciding between species.'),

  ('SF002', 'Bawal Hitam', 'Black Pomfret', 'Parastromateus niger',
   'species', 'Carangidae', 'marine demersal',
   'Demersal fish prized for steaming and Chinese-style preparations. Sold whole; the boneless flesh is why it commands a premium over kembung.',
   TRUE,
   'Demersal fish prized for steaming and Chinese-style preparations. Sold whole; the boneless flesh is why it commands a premium over kembung.'),

  ('SF003', 'Ikan Merah', 'Red Snapper', 'Lutjanus sebae',
   'species', 'Lutjanidae', 'marine demersal',
   'Sold generically as "ikan merah" across several Lutjanus species. The canonical record pins L. sebae, but market identity is genuinely mixed — the app must surface that uncertainty rather than hide it.',
   TRUE,
   'Sold generically as "ikan merah" across several Lutjanus species. The canonical record pins L. sebae, but market identity is genuinely mixed — the app must surface that uncertainty rather than hide it.'),

  ('SF004', 'Tilapia', 'Nile Tilapia', 'Oreochromis niloticus',
   'species', 'Cichlidae', 'freshwater',
   'Farmed freshwater fish, available year-round at a stable price. The most common responsible everyday swap when a wild species rates poorly.',
   TRUE,
   'Farmed freshwater fish, available year-round at a stable price. The most common responsible everyday swap when a wild species rates poorly.'),

  ('SF005', 'Kerapu Bintik', 'Orange-spotted Grouper', 'Epinephelus coioides',
   'species', 'Serranidae', 'marine demersal',
   'High-value reef fish, wild-caught or farmed depending on the seller. Price swings widely, and sustainability depends entirely on production method.',
   TRUE,
   'High-value reef fish, wild-caught or farmed depending on the seller. Price swings widely, and sustainability depends entirely on production method.')
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
-- seafood_alias
-- =========================================================
-- Search resolves here first. Aliases carry the spellings people actually type
-- ("ikan kembung", "merah", a bare genus), not just the tidy canonical name.
-- uq_seafood_alias_per_seafood dedupes on LOWER(TRIM(alias_name)), so two rows
-- for the same species that differ only in case or padding are the SAME alias.
-- A MARKET alias therefore has to be a genuinely different string from the
-- MALAY one, not the same words shouted in capitals.

INSERT INTO seafood_alias (
  seafood_alias_id, seafood_item_id, alias_name, language_code, alias_type, verified
)
SELECT
  suka_uuid5('seafood_alias:' || v.code || ':' || lower(trim(v.alias_name))),
  suka_uuid5('seafood_item:' || v.code),
  v.alias_name, v.language_code, v.alias_type::seafood_alias_type_enum, v.verified
FROM (VALUES
  -- SF001 Kembung
  ('SF001', 'Kembung',                 'ms', 'MALAY',          TRUE),
  ('SF001', 'Ikan Kembung',            'ms', 'MALAY',          TRUE),
  ('SF001', 'Pelaling',                'ms', 'MALAY',          TRUE),
  ('SF001', 'Indian Mackerel',         'en', 'ENGLISH_COMMON', TRUE),
  ('SF001', 'Rastrelliger kanagurta',  'la', 'SCIENTIFIC',     TRUE),
  ('SF001', 'IKAN KEMBUNG/PELALING',   'ms', 'MARKET',         TRUE),

  -- SF002 Bawal Hitam
  ('SF002', 'Bawal Hitam',             'ms', 'MALAY',          TRUE),
  ('SF002', 'Ikan Bawal Hitam',        'ms', 'MALAY',          TRUE),
  ('SF002', 'Black Pomfret',           'en', 'ENGLISH_COMMON', TRUE),
  ('SF002', 'Parastromateus niger',    'la', 'SCIENTIFIC',     TRUE),
  ('SF002', 'Bawal',                   'ms', 'SPELLING',       FALSE),

  -- SF003 Ikan Merah
  ('SF003', 'Ikan Merah',              'ms', 'MALAY',          TRUE),
  ('SF003', 'Merah',                   'ms', 'SPELLING',       FALSE),
  ('SF003', 'Red Snapper',             'en', 'ENGLISH_COMMON', TRUE),
  ('SF003', 'Lutjanus sebae',          'la', 'SCIENTIFIC',     TRUE),
  ('SF003', 'IKAN MERAH (SIAKAP MERAH)', 'ms', 'MARKET',       TRUE),

  -- SF004 Tilapia
  ('SF004', 'Tilapia',                 'ms', 'MALAY',          TRUE),
  ('SF004', 'Ikan Tilapia',            'ms', 'MALAY',          TRUE),
  ('SF004', 'Nile Tilapia',            'en', 'ENGLISH_COMMON', TRUE),
  ('SF004', 'Oreochromis niloticus',   'la', 'SCIENTIFIC',     TRUE),
  ('SF004', 'IKAN TILAPIA MERAH',      'ms', 'MARKET',         TRUE),

  -- SF005 Kerapu Bintik
  ('SF005', 'Kerapu Bintik',           'ms', 'MALAY',          TRUE),
  ('SF005', 'Kerapu',                  'ms', 'SPELLING',       FALSE),
  ('SF005', 'Orange-spotted Grouper',  'en', 'ENGLISH_COMMON', TRUE),
  ('SF005', 'Grouper',                 'en', 'ENGLISH_COMMON', FALSE),
  ('SF005', 'Epinephelus coioides',    'la', 'SCIENTIFIC',     TRUE)
) AS v(code, alias_name, language_code, alias_type, verified)
ON CONFLICT (seafood_alias_id) DO UPDATE SET
  alias_name    = EXCLUDED.alias_name,
  language_code = EXCLUDED.language_code,
  alias_type    = EXCLUDED.alias_type,
  verified      = EXCLUDED.verified;

-- =========================================================
-- wwf_assessment
-- =========================================================
-- Raw columns (*_raw) keep the source wording verbatim so a reviewer can always
-- see what WWF actually published next to how we mapped it. Four rows, not five:
-- see the header note on Kerapu Bintik.

INSERT INTO wwf_assessment (
  wwf_assessment_id, seafood_item_id, source_snapshot_id, source_record_key,
  common_name_raw, secondary_common_name_raw, scientific_name_raw, rating,
  origin_raw, origin_code, production_type, production_method_raw,
  production_method_code, certification_raw, context, notes_raw
)
SELECT
  suka_uuid5('wwf_assessment:wwf-sos-2026-handoff:' || v.source_record_key),
  suka_uuid5('seafood_item:' || v.code),
  suka_uuid5('source_snapshot:wwf_sos:wwf-sos-2026-handoff'),
  v.source_record_key,
  v.common_name_raw, v.secondary_common_name_raw, v.scientific_name_raw,
  v.rating::sustainability_rating_enum,
  v.origin_raw, v.origin_code, v.production_type, v.production_method_raw,
  v.production_method_code, v.certification_raw, v.context, v.notes_raw
FROM (VALUES
  ('SF001', 'wwf-sos-kembung-my-wild',
   'Indian Mackerel (Kembung)', 'Kembung / Pelaling', 'Rastrelliger kanagurta', 'BEST_CHOICE',
   'Malaysia', 'MY', 'WILD', 'Purse seine', 'PURSE_SEINE', NULL,
   'Applies to wild-caught Malaysian Indian mackerel taken by purse seine.',
   'Fast-growing small pelagic with a short life cycle; the everyday choice WWF SOS steers consumers toward. Verify against the live listing before any public claim.'),

  ('SF002', 'wwf-sos-black-pomfret-my-wild',
   'Black Pomfret (Bawal Hitam)', NULL, 'Parastromateus niger', 'REDUCE',
   'Malaysia / regional', 'MY', 'WILD', 'Trawl / drift net (varies by supplier)', 'TRAWL', NULL,
   'Applies where catch method is trawl or drift net.',
   'Demersal stock under sustained pressure and commonly taken by trawl. Rated REDUCE rather than AVOID because it remains a legal, managed fishery.'),

  ('SF003', 'wwf-sos-red-snapper-my-wild',
   'Red Snapper (Ikan Merah)', NULL, 'Lutjanus sebae', 'AVOID',
   'Malaysia / imported (varies)', 'MY', 'WILD', 'Trawl / hook and line (mixed snapper)', 'MIXED', NULL,
   'Mixed snapper group — stock identity rarely labelled at point of sale.',
   'Reef-associated, slow to mature, and sold as a mixed-species group so the specific stock is rarely identifiable at point of sale.'),

  ('SF004', 'wwf-sos-tilapia-my-farmed',
   'Tilapia', NULL, 'Oreochromis niloticus', 'BEST_CHOICE',
   'Malaysia (farmed)', 'MY', 'FARMED', 'Pond / cage aquaculture', 'AQUACULTURE', 'MyGAP where labelled',
   'Applies to responsibly farmed Malaysian tilapia.',
   'Responsibly farmed tilapia is an affordable everyday option that takes pressure off wild stocks. Prefer certified or MyGAP-labelled farms.')
) AS v(code, source_record_key, common_name_raw, secondary_common_name_raw, scientific_name_raw, rating,
       origin_raw, origin_code, production_type, production_method_raw,
       production_method_code, certification_raw, context, notes_raw)
ON CONFLICT (wwf_assessment_id) DO UPDATE SET
  rating                     = EXCLUDED.rating,
  common_name_raw            = EXCLUDED.common_name_raw,
  secondary_common_name_raw  = EXCLUDED.secondary_common_name_raw,
  scientific_name_raw        = EXCLUDED.scientific_name_raw,
  origin_raw                 = EXCLUDED.origin_raw,
  origin_code                = EXCLUDED.origin_code,
  production_type            = EXCLUDED.production_type,
  production_method_raw      = EXCLUDED.production_method_raw,
  production_method_code     = EXCLUDED.production_method_code,
  certification_raw          = EXCLUDED.certification_raw,
  context                    = EXCLUDED.context,
  notes_raw                  = EXCLUDED.notes_raw;

-- =========================================================
-- cooking_suitability
-- =========================================================
-- Team-curated, so every row points at the curation snapshot rather than an
-- external authority. suitability_score is 1-5; GET /cooking/{method} orders by
-- it descending.

INSERT INTO cooking_suitability (
  cooking_suitability_id, seafood_item_id, cooking_method_id, source_snapshot_id,
  suitability_score, reason_en, reason_ms, updated_at
)
SELECT
  suka_uuid5('cooking_suitability:' || v.code || ':' || v.method),
  suka_uuid5('seafood_item:' || v.code),
  suka_uuid5('cooking_method:' || v.method),
  suka_uuid5('source_snapshot:team_curated:curation-i1'),
  v.score::smallint,
  v.reason_en,
  v.reason_ms,
  TIMESTAMPTZ '2026-08-01 00:00:00+08'
FROM (VALUES
  -- SF001 Kembung — oily, firm, forgiving
  ('SF001', 'GRILL', 5, 'Oily flesh bastes itself over coals and the skin crisps without sticking.', 'Isinya berminyak, tidak melekat pada panggangan dan kulitnya rangup.'),
  ('SF001', 'CURRY', 5, 'Firm enough to hold its shape in a long-simmered gulai or asam pedas.', 'Cukup padat untuk kekal utuh dalam gulai atau asam pedas.'),
  ('SF001', 'FRY',   4, 'Small whole fish fry quickly and evenly.', 'Ikan kecil mudah digoreng sekata.'),
  ('SF001', 'SOUP',  3, 'Usable, though the oil can cloud a clear broth.', 'Boleh digunakan, tetapi minyaknya boleh mengeruhkan sup jernih.'),
  ('SF001', 'STEAM', 2, 'The strong flavour overwhelms the delicate seasoning steaming relies on.', 'Rasanya terlalu kuat untuk perasa halus masakan kukus.'),

  -- SF002 Bawal Hitam — the steaming fish
  ('SF002', 'STEAM', 5, 'The classic steamed pomfret: few bones, flesh that flakes cleanly.', 'Bawal kukus klasik: tulang sedikit, isi mudah dileraikan.'),
  ('SF002', 'FRY',   4, 'Flat body crisps evenly in a shallow pan.', 'Badan leper menjadi rangup sekata dalam kuali cetek.'),
  ('SF002', 'SOUP',  4, 'Bones and head give a clear soup real body.', 'Tulang dan kepala memberi sup jernih rasa yang mantap.'),
  ('SF002', 'GRILL', 3, 'Workable, but grilling wastes what you paid a premium for.', 'Boleh, tetapi memanggang membazirkan kelebihan ikan mahal ini.'),
  ('SF002', 'CURRY', 3, 'Holds up in gravy, though the delicate flavour is lost.', 'Tahan dalam kuah, tetapi rasa halusnya hilang.'),

  -- SF003 Ikan Merah — firm, versatile
  ('SF003', 'STEAM', 5, 'Firm white flesh stays intact and stays moist.', 'Isi putih padat kekal utuh dan lembap.'),
  ('SF003', 'GRILL', 4, 'Thick steaks take direct heat without falling apart.', 'Kepingan tebal tahan panas terus tanpa hancur.'),
  ('SF003', 'FRY',   4, 'Fillets hold together well in the pan.', 'Isi filet kekal utuh dalam kuali.'),
  ('SF003', 'CURRY', 4, 'Dense flesh survives a long simmer in rich gravy.', 'Isi padat tahan direneh lama dalam kuah pekat.'),
  ('SF003', 'BAKE',  3, 'Good whole-baked, though it dries if overcooked.', 'Sesuai dibakar utuh, tetapi kering jika terlebih masak.'),

  -- SF004 Tilapia — the everyday workhorse
  ('SF004', 'FRY',   5, 'The default weeknight fry: mild, cheap, cooks through fast.', 'Gorengan harian: rasa lembut, murah, cepat masak.'),
  ('SF004', 'GRILL', 4, 'Mild flesh takes on marinade and smoke well.', 'Isi lembut menyerap perapan dan asap dengan baik.'),
  ('SF004', 'CURRY', 4, 'Neutral flavour absorbs whatever gravy it sits in.', 'Rasa neutral menyerap kuah dengan baik.'),
  ('SF004', 'SOUP',  4, 'Common in clear fish soup; the flesh does not break up.', 'Biasa dalam sup ikan jernih; isinya tidak hancur.'),
  ('SF004', 'STEAM', 3, 'Fine steamed, but freshwater earthiness needs strong ginger.', 'Boleh dikukus, tetapi bau tanah air tawar perlu banyak halia.'),

  -- SF005 Kerapu Bintik — premium, best treated simply
  ('SF005', 'STEAM', 5, 'Premium steamed kerapu — the preparation the price is for.', 'Kerapu kukus premium — cara masakan yang berbaloi dengan harganya.'),
  ('SF005', 'GRILL', 4, 'Firm steaks grill cleanly without drying.', 'Kepingan padat dipanggang tanpa menjadi kering.'),
  ('SF005', 'SOUP',  4, 'Bones make an unusually rich stock.', 'Tulangnya menghasilkan sup yang sangat berperisa.'),
  ('SF005', 'BAKE',  3, 'Works wrapped and baked whole.', 'Sesuai dibalut dan dibakar utuh.'),
  ('SF005', 'CURRY', 2, 'Technically fine, but heavy spice buries an expensive fish.', 'Boleh, tetapi rempah pekat menenggelamkan ikan mahal ini.')
) AS v(code, method, score, reason_en, reason_ms)
ON CONFLICT (cooking_suitability_id) DO UPDATE SET
  suitability_score = EXCLUDED.suitability_score,
  reason_en         = EXCLUDED.reason_en,
  reason_ms         = EXCLUDED.reason_ms,
  updated_at        = EXCLUDED.updated_at;

COMMIT;
