-- =========================================================
-- 07_cooking_cv_expansion.sql
-- =========================================================
-- Cooking suitability for the seven species added in 05 so the scanner can see
-- them (SF006–SF012).
--
-- Why this file exists
-- --------------------
-- 05 gave the new species an identity: a UUID, a name and aliases. That is
-- enough for the class map to resolve and for the join to succeed, and it is
-- not enough for the app. A shopper who scans a tenggiri and lands on a profile
-- with an empty "how to cook it" section has been shown a working feature that
-- does nothing useful. The scan resolving to a canonical id is only worth
-- something if that id leads somewhere.
--
-- What is deliberately NOT here
-- -----------------------------
-- WWF sustainability ratings. These seven species have no wwf_assessment row
-- and will report UNDETERMINED until someone transcribes the Save Our Seafood
-- guide for them. That is the correct behaviour, not a gap to paper over: a
-- default rating reads to a shopper as approval, and inventing one would be the
-- single worst thing this application could do. UNDETERMINED is an honest
-- answer; a guessed "GOOD CHOICE" is not.
--
-- Provenance
-- ----------
-- Team-curated, like 04, but under its own snapshot rather than reusing
-- curation-i1. These rows were written later, by a different pass, against a
-- different species set; folding them into the I1 snapshot would misdate them
-- and make the two batches impossible to tell apart when one is revised.
--
-- Scores are 1–5 and reflect how Malaysian home and hawker kitchens actually
-- treat these fish — oily pelagics grill and curry, flat pomfrets steam, small
-- scads fry whole. They are editorial judgements, which is exactly why they
-- carry a curation snapshot instead of an authority citation.

BEGIN;

-- The curation pass that produced the rows below.
INSERT INTO source_snapshot (
  source_snapshot_id, data_source_id, version_label,
  retrieved_at, collection_method, notes
) VALUES (
  suka_uuid5('source_snapshot:team_curated:curation-cv-expansion'),
  suka_uuid5('data_source:team_curated'),
  'curation-cv-expansion',
  TIMESTAMPTZ '2026-08-30 00:00:00+08',
  'TEAM_CURATED',
  'Cooking suitability for the seven species added for CV coverage (SF006-SF012). '
  'Editorial judgement based on common Malaysian preparation, not an external authority.'
)
ON CONFLICT (source_snapshot_id) DO UPDATE SET
  version_label = EXCLUDED.version_label,
  notes         = EXCLUDED.notes;

INSERT INTO cooking_suitability (
  cooking_suitability_id, seafood_item_id, cooking_method_id, source_snapshot_id,
  suitability_score, reason_en, reason_ms, updated_at
)
SELECT
  suka_uuid5('cooking_suitability:' || v.code || ':' || v.method),
  suka_uuid5('seafood_item:' || v.code),
  suka_uuid5('cooking_method:' || v.method),
  suka_uuid5('source_snapshot:team_curated:curation-cv-expansion'),
  v.score::smallint,
  v.reason_en,
  v.reason_ms,
  TIMESTAMPTZ '2026-08-30 00:00:00+08'
FROM (VALUES
  -- SF006 Bawal Putih (Pampus argenteus) — the premium steaming pomfret
  ('SF006', 'STEAM', 5, 'The festive steamed fish: fine white flesh, very few bones.', 'Ikan kukus perayaan: isi putih halus, tulang sangat sedikit.'),
  ('SF006', 'FRY',   4, 'Flat body crisps evenly, though it is an expensive fish to fry.', 'Badan leper menjadi rangup sekata, tetapi mahal untuk digoreng.'),
  ('SF006', 'SOUP',  3, 'Makes a clean, delicate broth.', 'Menghasilkan sup jernih yang halus rasanya.'),
  ('SF006', 'GRILL', 3, 'Possible, but direct heat dries the lean flesh quickly.', 'Boleh, tetapi panas terus cepat mengeringkan isinya yang tidak berlemak.'),
  ('SF006', 'CURRY', 2, 'Heavy spice buries the delicate flavour you paid for.', 'Rempah pekat menenggelamkan rasa halus yang mahal ini.'),

  -- SF007 Cencaru (Megalaspis cordyla) — the stuffed-and-fried fish
  ('SF007', 'FRY',   5, 'The classic cencaru sumbat: split, stuffed with sambal, fried whole.', 'Cencaru sumbat klasik: dibelah, disumbat sambal, digoreng utuh.'),
  ('SF007', 'GRILL', 4, 'Firm dark flesh takes coals well and does not fall apart.', 'Isi gelap yang padat sesuai dipanggang dan tidak hancur.'),
  ('SF007', 'CURRY', 4, 'Dense enough to survive a long simmer in asam pedas.', 'Cukup padat untuk direneh lama dalam asam pedas.'),
  ('SF007', 'SOUP',  2, 'Strong oily flavour clouds a clear soup.', 'Rasa berminyaknya mengeruhkan sup jernih.'),
  ('SF007', 'STEAM', 2, 'Too strongly flavoured for steaming.', 'Rasanya terlalu kuat untuk dikukus.'),

  -- SF008 Jenahak (Lutjanus johnii) — firm snapper, genuinely versatile
  ('SF008', 'STEAM', 5, 'Firm white flesh stays intact and stays moist — the default treatment.', 'Isi putih padat kekal utuh dan lembap — cara paling biasa.'),
  ('SF008', 'GRILL', 5, 'Thick steaks take direct heat without breaking up.', 'Kepingan tebal tahan panas terus tanpa hancur.'),
  ('SF008', 'CURRY', 4, 'Holds its shape through a long-simmered gulai.', 'Kekal utuh dalam gulai yang direneh lama.'),
  ('SF008', 'BAKE',  4, 'Good baked whole; the skin protects the flesh.', 'Sesuai dibakar utuh; kulitnya melindungi isi.'),
  ('SF008', 'FRY',   3, 'Fine, but frying a whole snapper is an expensive way to cook it.', 'Boleh, tetapi menggoreng jenahak utuh membazir.'),

  -- SF009 Kerisi (Nemipterus japonicus) — small, cheap, fries whole
  ('SF009', 'FRY',   5, 'Small enough to fry whole and eat off the bone.', 'Cukup kecil untuk digoreng utuh dan dimakan terus dari tulang.'),
  ('SF009', 'SOUP',  4, 'Sweet flesh and plenty of bone make a good clear soup.', 'Isi manis dan banyak tulang menghasilkan sup jernih yang sedap.'),
  ('SF009', 'CURRY', 4, 'A standard everyday gulai fish.', 'Ikan gulai harian yang biasa.'),
  ('SF009', 'STEAM', 3, 'Workable, though it is bony for steaming.', 'Boleh, tetapi banyak tulang untuk dikukus.'),
  ('SF009', 'GRILL', 2, 'Thin body dries out before the skin colours.', 'Badan nipis menjadi kering sebelum kulitnya perang.'),

  -- SF010 Pelata (Alepes melanoptera) — small oily scad
  ('SF010', 'FRY',   5, 'Fried whole and crisp is how it is nearly always eaten.', 'Digoreng utuh sehingga rangup — cara paling biasa.'),
  ('SF010', 'CURRY', 4, 'Oily flesh stands up to a sour, spicy gravy.', 'Isi berminyak sesuai dengan kuah masam pedas.'),
  ('SF010', 'GRILL', 3, 'Oiliness helps, but the fish is small for a grill.', 'Minyaknya membantu, tetapi ikannya kecil untuk dipanggang.'),
  ('SF010', 'SOUP',  2, 'Oil clouds the broth.', 'Minyaknya mengeruhkan sup.'),
  ('SF010', 'STEAM', 2, 'Strong flavour and small size make steaming a poor fit.', 'Rasa kuat dan saiz kecil tidak sesuai dikukus.'),

  -- SF011 Selar Kuning (Selaroides leptolepis) — the cheap frying staple
  ('SF011', 'FRY',   5, 'The everyday fried fish: cheap, small, crisp in minutes.', 'Ikan goreng harian: murah, kecil, rangup dalam beberapa minit.'),
  ('SF011', 'CURRY', 4, 'Common in a quick weekday gulai or asam pedas.', 'Biasa dalam gulai atau asam pedas harian.'),
  ('SF011', 'GRILL', 3, 'Grills acceptably, but is more usually fried.', 'Boleh dipanggang, tetapi lebih biasa digoreng.'),
  ('SF011', 'SOUP',  3, 'Adds flavour, though small bones are a nuisance.', 'Menambah rasa, tetapi tulang halusnya menyusahkan.'),
  ('SF011', 'STEAM', 2, 'Too small and too strongly flavoured to steam well.', 'Terlalu kecil dan rasanya terlalu kuat untuk dikukus.'),

  -- SF012 Tenggiri (Scomberomorus commerson) — sold as steaks, the curry fish
  ('SF012', 'CURRY', 5, 'The standard fish for gulai and asam pedas; steaks hold together.', 'Ikan gulai dan asam pedas yang standard; kepingannya kekal utuh.'),
  ('SF012', 'GRILL', 5, 'Thick firm steaks are made for direct heat.', 'Kepingan tebal dan padat sangat sesuai untuk panggangan.'),
  ('SF012', 'FRY',   4, 'Steaks fry well; also the fish used for otak-otak and keropok.', 'Kepingan sesuai digoreng; juga ikan untuk otak-otak dan keropok.'),
  ('SF012', 'BAKE',  3, 'Good baked, but dries if taken past done.', 'Sesuai dibakar, tetapi kering jika terlebih masak.'),
  ('SF012', 'STEAM', 2, 'Dense steaks turn dry and fibrous when steamed.', 'Kepingan padat menjadi kering dan berserabut apabila dikukus.')
) AS v(code, method, score, reason_en, reason_ms)
ON CONFLICT (cooking_suitability_id) DO UPDATE SET
  suitability_score = EXCLUDED.suitability_score,
  reason_en         = EXCLUDED.reason_en,
  reason_ms         = EXCLUDED.reason_ms,
  updated_at        = EXCLUDED.updated_at;

-- =========================================================
-- Guard rails
-- =========================================================
DO $$
DECLARE
  n_missing INT;
  n_rows    INT;
BEGIN
  -- Every species the scanner can return must lead somewhere. A scannable fish
  -- with no cooking rows renders an empty profile — the feature appears to work
  -- and delivers nothing.
  SELECT count(*) INTO n_missing
    FROM seafood_item s
   WHERE s.supports_cv
     AND NOT EXISTS (SELECT 1 FROM cooking_suitability c
                      WHERE c.seafood_item_id = s.seafood_item_id);
  IF n_missing > 0 THEN
    RAISE EXCEPTION '% CV-scannable species have no cooking_suitability rows — '
                    'scanning them would open an empty profile', n_missing;
  END IF;

  SELECT count(*) INTO n_rows
    FROM cooking_suitability c
    JOIN seafood_item s USING (seafood_item_id)
   WHERE s.code IN ('SF006','SF007','SF008','SF009','SF010','SF011','SF012');
  IF n_rows < 35 THEN
    RAISE EXCEPTION 'expected at least 35 cooking rows for SF006-SF012, found %', n_rows;
  END IF;
END $$;

COMMIT;
