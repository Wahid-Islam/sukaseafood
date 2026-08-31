-- =========================================================
-- 05_seafood_cv_expansion.sql
-- =========================================================
-- Canonical rows for the seven species the image dataset covers that
-- 04_seafood_i1.sql did not.
--
-- Why this file exists, and why it is separate from 04:
--   04 seeds the five species the I1 product documents froze. The image
--   corpus in sukaseafood-fish-images covers nine species, overlapping the
--   frozen five on only two (SF001 Kembung, SF002 Bawal Hitam). The scanner
--   can only recognise what it has images for, so the catalogue has to carry
--   a canonical row — and therefore a stable seafood_item_id — for every
--   species the model can name. Without that there is nothing to hang WWF,
--   price or cooking data off when the scanner returns one.
--
--   Keeping it in its own file leaves 04 as the record of the frozen I1
--   scope, and makes the expansion reviewable on its own terms.
--
-- supports_cv is the honest divider, not a decoration:
--   TRUE  — the model has training images and can return this species
--   FALSE — canonical row exists, the model cannot recognise it yet
--
--   SF003 Ikan Merah, SF004 Tilapia and SF005 Kerapu Bintik keep their rows
--   and all their downstream WWF / price / cooking data, but flip to
--   supports_cv = FALSE, because the dataset has no images of them. Claiming
--   otherwise would let /identify offer a species the model was never taught.
--
-- Every scientific name below is the one the dataset's own manifest records
-- for that folder. Note especially that JENAHAK is Lutjanus johnii, a
-- different species from SF003's Lutjanus sebae — both are sold as "ikan
-- merah" in the market, and conflating them in the catalogue would bake a
-- real-world ambiguity into the data model.

BEGIN;

-- =========================================================
-- seafood_item — the seven additions
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
  ('SF006', 'Bawal Putih', 'Silver Pomfret', 'Pampus argenteus',
   'species', 'Stromateidae', 'marine demersal',
   'The premium pomfret, consistently priced well above bawal hitam. Sold whole for steaming, and the price gap between the two bawal is one of the clearest everyday trade-offs a shopper faces.',
   TRUE,
   'Distinct species from SF002 despite sharing the bawal name; the two are routinely compared at the counter.'),

  ('SF007', 'Cencaru', 'Hardtail Scad', 'Megalaspis cordyla',
   'species', 'Carangidae', 'marine pelagic',
   'Firm-fleshed scad with a hard keeled tail, usually stuffed with sambal and fried. Cheap, abundant, and a staple of Malay home cooking.',
   TRUE,
   'One of three Carangidae in the catalogue; the keeled caudal peduncle is its clearest visual marker.'),

  ('SF008', 'Jenahak', 'John''s Snapper', 'Lutjanus johnii',
   'species', 'Lutjanidae', 'marine demersal',
   'High-value snapper sold whole or in steaks, common in Chinese restaurant cooking. Frequently sold under the generic "ikan merah" label alongside other Lutjanus species.',
   TRUE,
   'Lutjanus johnii, NOT SF003 Lutjanus sebae. Both trade as ikan merah; the catalogue keeps them separate because their prices and sustainability profiles differ.'),

  ('SF009', 'Kerisi', 'Japanese Threadfin Bream', 'Nemipterus japonicus',
   'species', 'Nemipteridae', 'marine demersal',
   'Small pink-toned bream landed in quantity by trawlers. Inexpensive, often fried whole or turned into fish paste and keropok.',
   TRUE,
   'Heavily trawl-caught; production method matters more than species for its sustainability rating.'),

  ('SF010', 'Pelata', 'Blackfin Scad', 'Alepes melanoptera',
   'species', 'Carangidae', 'marine pelagic',
   'Small silver scad sold by the heap, typically fried or made into masak lemak. Among the cheapest fish on the slab.',
   TRUE,
   'Thinnest coverage of the nine in the image corpus; treat its scanner accuracy as provisional.'),

  ('SF011', 'Selar Kuning', 'Yellowstripe Scad', 'Selaroides leptolepis',
   'species', 'Carangidae', 'marine pelagic',
   'Small scad with a bright yellow lateral stripe, sold in bulk and fried whole. A everyday-cheap alternative when kembung is expensive.',
   TRUE,
   'The yellow stripe is the strongest single visual cue in the catalogue, and the reason this class should be among the easiest to recognise.'),

  ('SF012', 'Tenggiri', 'Narrow-barred Spanish Mackerel', 'Scomberomorus commerson',
   'species', 'Scombridae', 'marine pelagic',
   'Large mackerel sold in steaks rather than whole, and the base of keropok lekor and fish balls. Commands a high price per kilo.',
   TRUE,
   'Usually retailed as cut steaks, so a whole-fish scanner will meet it less often than its market share suggests.')
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
-- supports_cv correction for the frozen five
-- =========================================================
-- The dataset has images for SF001 and SF002 only. The other three keep every
-- row they own — WWF assessment, cooking suitability, price mappings — and
-- simply stop claiming the scanner can find them.
UPDATE seafood_item
   SET supports_cv = FALSE, updated_at = now()
 WHERE code IN ('SF003', 'SF004', 'SF005')
   AND supports_cv IS DISTINCT FROM FALSE;

-- =========================================================
-- seafood_alias — search must reach the new species
-- =========================================================
-- Without these, a user could scan a fish, get a confirmed seafood_item_id,
-- and then fail to find that same fish by typing its name.
INSERT INTO seafood_alias (
  seafood_alias_id, seafood_item_id, alias_name, language_code, alias_type, verified
)
SELECT
  suka_uuid5('seafood_alias:' || v.code || ':' || lower(trim(v.alias_name))),
  suka_uuid5('seafood_item:' || v.code),
  v.alias_name, v.language_code, v.alias_type::seafood_alias_type_enum, v.verified
FROM (VALUES
  -- SF006 Bawal Putih
  ('SF006', 'Bawal Putih',                    'ms', 'MALAY',          TRUE),
  ('SF006', 'Ikan Bawal Putih',               'ms', 'MALAY',          TRUE),
  ('SF006', 'Silver Pomfret',                 'en', 'ENGLISH_COMMON', TRUE),
  ('SF006', 'White Pomfret',                  'en', 'ENGLISH_COMMON', FALSE),
  ('SF006', 'Pampus argenteus',               'la', 'SCIENTIFIC',     TRUE),

  -- SF007 Cencaru
  ('SF007', 'Cencaru',                        'ms', 'MALAY',          TRUE),
  ('SF007', 'Ikan Cencaru',                   'ms', 'MALAY',          TRUE),
  ('SF007', 'Chencaru',                       'ms', 'SPELLING',       FALSE),
  ('SF007', 'Hardtail Scad',                  'en', 'ENGLISH_COMMON', TRUE),
  ('SF007', 'Torpedo Scad',                   'en', 'ENGLISH_COMMON', FALSE),
  ('SF007', 'Megalaspis cordyla',             'la', 'SCIENTIFIC',     TRUE),

  -- SF008 Jenahak
  ('SF008', 'Jenahak',                        'ms', 'MALAY',          TRUE),
  ('SF008', 'Ikan Jenahak',                   'ms', 'MALAY',          TRUE),
  ('SF008', 'John''s Snapper',                'en', 'ENGLISH_COMMON', TRUE),
  ('SF008', 'Golden Snapper',                 'en', 'ENGLISH_COMMON', FALSE),
  ('SF008', 'Lutjanus johnii',                'la', 'SCIENTIFIC',     TRUE),

  -- SF009 Kerisi
  ('SF009', 'Kerisi',                         'ms', 'MALAY',          TRUE),
  ('SF009', 'Ikan Kerisi',                    'ms', 'MALAY',          TRUE),
  ('SF009', 'Japanese Threadfin Bream',       'en', 'ENGLISH_COMMON', TRUE),
  ('SF009', 'Threadfin Bream',                'en', 'ENGLISH_COMMON', FALSE),
  ('SF009', 'Nemipterus japonicus',           'la', 'SCIENTIFIC',     TRUE),

  -- SF010 Pelata
  ('SF010', 'Pelata',                         'ms', 'MALAY',          TRUE),
  ('SF010', 'Ikan Pelata',                    'ms', 'MALAY',          TRUE),
  ('SF010', 'Blackfin Scad',                  'en', 'ENGLISH_COMMON', TRUE),
  ('SF010', 'Alepes melanoptera',             'la', 'SCIENTIFIC',     TRUE),

  -- SF011 Selar Kuning
  ('SF011', 'Selar Kuning',                   'ms', 'MALAY',          TRUE),
  ('SF011', 'Ikan Selar Kuning',              'ms', 'MALAY',          TRUE),
  ('SF011', 'Selar',                          'ms', 'SPELLING',       FALSE),
  ('SF011', 'Yellowstripe Scad',              'en', 'ENGLISH_COMMON', TRUE),
  ('SF011', 'Selaroides leptolepis',          'la', 'SCIENTIFIC',     TRUE),

  -- SF012 Tenggiri
  ('SF012', 'Tenggiri',                       'ms', 'MALAY',          TRUE),
  ('SF012', 'Ikan Tenggiri',                  'ms', 'MALAY',          TRUE),
  ('SF012', 'Narrow-barred Spanish Mackerel', 'en', 'ENGLISH_COMMON', TRUE),
  ('SF012', 'Spanish Mackerel',               'en', 'ENGLISH_COMMON', FALSE),
  ('SF012', 'Scomberomorus commerson',        'la', 'SCIENTIFIC',     TRUE)
) AS v(code, alias_name, language_code, alias_type, verified)
ON CONFLICT (seafood_alias_id) DO UPDATE SET
  alias_name    = EXCLUDED.alias_name,
  language_code = EXCLUDED.language_code,
  alias_type    = EXCLUDED.alias_type,
  verified      = EXCLUDED.verified;

-- =========================================================
-- Guard rails
-- =========================================================
DO $$
DECLARE
  n_items INT;
  n_cv    INT;
BEGIN
  -- A floor, not an equality. Later seeds add canonical rows for species the
  -- scanner cannot see but other subsystems need (08 adds the two forecast-only
  -- fish), and on a re-run this guard would otherwise fail against the rows a
  -- later file legitimately inserted.
  SELECT count(*) INTO n_items FROM seafood_item WHERE active;
  IF n_items < 12 THEN
    RAISE EXCEPTION 'expected at least 12 active seafood_item rows after expansion, found %', n_items;
  END IF;

  SELECT count(*) INTO n_cv FROM seafood_item WHERE supports_cv;
  IF n_cv <> 9 THEN
    RAISE EXCEPTION 'expected 9 CV-supported species, found % — supports_cv must match the trained class map', n_cv;
  END IF;
END $$;

COMMIT;
