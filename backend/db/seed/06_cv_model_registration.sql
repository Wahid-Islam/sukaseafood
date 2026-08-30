-- =========================================================
-- 06_cv_model_registration.sql   ** GENERATED FILE — DO NOT EDIT **
-- =========================================================
-- Regenerate with:  cd cv && python scripts/register_model.py
--
-- Source of truth: cv/handoff/class_map.json and cv/handoff/model_card.json,
-- both written by scripts/export_onnx.py alongside the model.onnx they
-- describe. Editing this file by hand desynchronises it from the artifact the
-- server actually loads, and the resulting mislabelling produces no error —
-- only wrong fish.
--
-- Applied automatically by the backend seed loader (backend/app/seed), after
-- 04_seafood_i1.sql and 05_seafood_cv_expansion.sql, which create the
-- seafood_item rows this file joins to.
--
-- Invariants enforced at the bottom of this file:
--   * exactly one active cv_model_version, so the adapter and the resolution
--     query can never disagree about which class map applies
--   * one mapping per class the model emits, each pointing at a seafood_item
--     that exists and has supports_cv = TRUE
--   * no species advertised as scannable without a mapping to back it up


BEGIN;

-- Retire any previously active model. Two active versions would leave the
-- resolution query ambiguous, and the adapter would keep serving whichever
-- package happens to be on disk.
UPDATE cv_model_version SET active = FALSE WHERE active;

INSERT INTO cv_model_version (
  cv_model_version_id, version_name, input_contract, metrics,
  confidence_threshold, active
) VALUES (
  suka_uuid5('cv_model_version:cv-i1-2026-08-30'),
  'cv-i1-2026-08-30',
  '{
    "backbone": "mobilenetv3_small_100",
    "image_size": 224,
    "resize_shorter_side": 256,
    "colour_order": "RGB",
    "scale": "0-1",
    "mean": [
        0.485,
        0.456,
        0.406
    ],
    "std": [
        0.229,
        0.224,
        0.225
    ],
    "layout": "NCHW",
    "dtype": "float32",
    "interpolation": "bilinear",
    "exif_transpose": true,
    "max_upload_bytes": 10485760,
    "accepted_formats": [
        "JPEG",
        "PNG",
        "WEBP"
    ]
}'::jsonb,
  '{
    "split": "test_clean",
    "n": 200,
    "accuracy": 0.78,
    "macro_f1": 0.7171,
    "top3_hit_rate": 0.94,
    "backbone": "mobilenetv3_small_100",
    "domain": "WILD",
    "caveat": "Measured on wild and museum-specimen imagery from iNaturalist, GBIF and ALA. Malaysian retail-counter performance is unmeasured and will be lower — different lighting, ice, cut fish, overlapping bodies.",
    "weakest_classes": [
        "SF010 Pelata",
        "SF009 Kerisi"
    ],
    "labels_verified": false
}'::jsonb,
  0.5000,
  TRUE
)
ON CONFLICT (cv_model_version_id) DO UPDATE SET
  version_name         = EXCLUDED.version_name,
  input_contract       = EXCLUDED.input_contract,
  metrics              = EXCLUDED.metrics,
  confidence_threshold = EXCLUDED.confidence_threshold,
  active               = TRUE;

-- =========================================================
-- cv_class_mapping — frozen model class index -> canonical seafood_item
-- =========================================================
-- The join that makes a scanned fish the same entity as a searched one.
-- The model never learns a UUID; it emits SF00x, and this table turns that
-- into the key price, WWF, cooking and favourites all hang off.
INSERT INTO cv_class_mapping (
  cv_class_mapping_id, cv_model_version_id, seafood_item_id,
  model_class_label, model_class_index
)
SELECT
  suka_uuid5('cv_class_mapping:cv-i1-2026-08-30:' || v.code),
  suka_uuid5('cv_model_version:cv-i1-2026-08-30'),
  s.seafood_item_id,
  v.code,
  v.idx
FROM (VALUES
  (0, 'SF001'),   -- Kembung / Pelaling  Rastrelliger kanagurta
  (1, 'SF002'),   -- Bawal Hitam         Parastromateus niger
  (2, 'SF006'),   -- Bawal Putih         Pampus argenteus
  (3, 'SF007'),   -- Cencaru             Megalaspis cordyla
  (4, 'SF008'),   -- Jenahak             Lutjanus johnii
  (5, 'SF009'),   -- Kerisi              Nemipterus japonicus
  (6, 'SF010'),   -- Pelata              Alepes melanoptera
  (7, 'SF011'),   -- Selar Kuning        Selaroides leptolepis
  (8, 'SF012')   -- Tenggiri            Scomberomorus commerson
) AS v(idx, code)
JOIN seafood_item s ON s.code = v.code
ON CONFLICT (cv_class_mapping_id) DO UPDATE SET
  seafood_item_id   = EXCLUDED.seafood_item_id,
  model_class_label = EXCLUDED.model_class_label,
  model_class_index = EXCLUDED.model_class_index;

-- =========================================================
-- Guard rails
-- =========================================================
-- Each of these catches a failure that is otherwise silent: the request
-- succeeds, the UUID is real, the profile renders, and the fish is wrong.
DO $$
DECLARE
  n_active   INT;
  n_mappings INT;
  n_bad      INT;
  n_gap      INT;
  n_joined   INT;
BEGIN
  SELECT count(*) INTO n_active FROM cv_model_version WHERE active;
  IF n_active <> 1 THEN
    RAISE EXCEPTION 'expected exactly 1 active cv_model_version, found %', n_active;
  END IF;

  -- The JOIN above drops silently if a code is missing, so count what
  -- actually landed rather than trusting the INSERT to have run 9 times.
  SELECT count(*) INTO n_mappings
    FROM cv_class_mapping m
    JOIN cv_model_version v USING (cv_model_version_id)
   WHERE v.active;
  IF n_mappings <> 9 THEN
    RAISE EXCEPTION 'active model has % class mappings, expected 9 — a seafood_item code in the class map does not exist', n_mappings;
  END IF;

  -- Model class indices must address 0..N-1 exactly, because the adapter
  -- looks up the argmax of the output vector by position.
  SELECT count(DISTINCT m.model_class_index) INTO n_joined
    FROM cv_class_mapping m
    JOIN cv_model_version v USING (cv_model_version_id)
   WHERE v.active AND m.model_class_index BETWEEN 0 AND 8;
  IF n_joined <> 9 THEN
    RAISE EXCEPTION 'class indices are not a complete 0..8 set';
  END IF;

  -- A mapping to a species flagged not-CV-supported means the catalogue and
  -- the model disagree about what the scanner can see.
  SELECT count(*) INTO n_bad
    FROM cv_class_mapping m
    JOIN cv_model_version v USING (cv_model_version_id)
    JOIN seafood_item s USING (seafood_item_id)
   WHERE v.active AND NOT s.supports_cv;
  IF n_bad > 0 THEN
    RAISE EXCEPTION '% mapped species have supports_cv = FALSE', n_bad;
  END IF;

  -- Every species advertised as scannable must be in the class map, or the
  -- catalogue promises a fish the model was never taught.
  SELECT count(*) INTO n_gap
    FROM seafood_item s
   WHERE s.supports_cv
     AND NOT EXISTS (
       SELECT 1 FROM cv_class_mapping m
       JOIN cv_model_version v USING (cv_model_version_id)
       WHERE v.active AND m.seafood_item_id = s.seafood_item_id);
  IF n_gap > 0 THEN
    RAISE EXCEPTION '% species have supports_cv = TRUE but no class mapping', n_gap;
  END IF;
END $$;

COMMIT;

-- Verification:
--   SELECT v.version_name, v.confidence_threshold, m.model_class_index,
--          m.model_class_label, s.code, s.display_name_en, s.seafood_item_id
--     FROM cv_model_version v
--     JOIN cv_class_mapping m USING (cv_model_version_id)
--     JOIN seafood_item s USING (seafood_item_id)
--    WHERE v.active ORDER BY m.model_class_index;
