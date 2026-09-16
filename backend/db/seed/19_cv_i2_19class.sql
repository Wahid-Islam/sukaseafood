-- =========================================================
-- 19_cv_i2_19class.sql
-- =========================================================
-- Iteration 2 19-class ConvNeXt-Tiny scanner.
-- Mapping SQL from:  python cv/scripts/register_model.py \
--   --handoff cv/sukaseafood_cv_handoff --out backend/db/seed/19_cv_i2_19class.sql
-- Class codes were remapped from the package placeholders (SF013-SF026)
-- onto the 54-fish WWF catalogue. class_index 0..18 is unchanged.
-- Runs after 10_wwf_catalogue_54.sql and 13_cv_i2_5class.sql.
--
-- Scannable (19):
--   SF001 Kembung, SF002 Bawal Hitam, SF003 Ikan Merah, SF004 Tilapia,
--   SF005 Kerapu Bintik, SF007 Cencaru, SF008 Jenahak, SF012 Tenggiri,
--   SF014 Siakap Putih, SF016 Alaskan Pollock, SF019 Atlantic Cod,
--   SF020 Atlantic Salmon, SF037 Kerapu Harimau, SF038 Kerapu Kertang,
--   SF039 Kerapu Lumpur, SF041 Kerapu Tikus, SF044 Kunyit-kunyit,
--   SF046 Mameng, SF051 Siakap Merah.

BEGIN;

UPDATE seafood_item
   SET supports_cv = code IN (
         'SF001', 'SF002', 'SF003', 'SF004', 'SF005',
         'SF007', 'SF008', 'SF012', 'SF014', 'SF016',
         'SF019', 'SF020', 'SF037', 'SF038', 'SF039',
         'SF041', 'SF044', 'SF046', 'SF051'
       ),
       updated_at = now();

DO $$
DECLARE
  n_cv INT;
BEGIN
  SELECT count(*) INTO n_cv FROM seafood_item WHERE supports_cv;
  IF n_cv <> 19 THEN
    RAISE EXCEPTION 'expected 19 CV-supported species after I2 19-class cutover, found %', n_cv;
  END IF;
END $$;

-- Retire any previously active model. Two active versions would leave the
-- resolution query ambiguous, and the adapter would keep serving whichever
-- package happens to be on disk.
UPDATE cv_model_version SET active = FALSE WHERE active;

INSERT INTO cv_model_version (
  cv_model_version_id, version_name, input_contract, metrics,
  confidence_threshold, active
) VALUES (
  suka_uuid5('cv_model_version:cv-i2-19class-convnext-tiny-20260915-original-train'),
  'cv-i2-19class-convnext-tiny-20260915-original-train',
  '{
    "backbone": "convnext_tiny",
    "image_size": 224,
    "resize_shorter_side": 236,
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
    "n": 235,
    "accuracy": 0.7915,
    "macro_f1": 0.7802,
    "top3_hit_rate": 0.9191,
    "backbone": "convnext_tiny",
    "domain": "WILD",
    "caveat": "Measured on wild and museum-specimen imagery from iNaturalist, GBIF and ALA. Malaysian retail-counter performance is unmeasured and will be lower -- different lighting, ice, cut fish, overlapping bodies.",
    "weakest_classes": [],
    "labels_verified": false
}'::jsonb,
  0.3000,
  TRUE
)
ON CONFLICT (cv_model_version_id) DO UPDATE SET
  version_name         = EXCLUDED.version_name,
  input_contract       = EXCLUDED.input_contract,
  metrics              = EXCLUDED.metrics,
  confidence_threshold = EXCLUDED.confidence_threshold,
  active               = TRUE;

-- =========================================================
-- cv_class_mapping -- frozen model class index -> canonical seafood_item
-- =========================================================
-- The join that makes a scanned fish the same entity as a searched one.
-- The model never learns a UUID; it emits SF00x, and this table turns that
-- into the key price, WWF, cooking and favourites all hang off.
INSERT INTO cv_class_mapping (
  cv_class_mapping_id, cv_model_version_id, seafood_item_id,
  model_class_label, model_class_index
)
SELECT
  suka_uuid5('cv_class_mapping:cv-i2-19class-convnext-tiny-20260915-original-train:' || v.code),
  suka_uuid5('cv_model_version:cv-i2-19class-convnext-tiny-20260915-original-train'),
  s.seafood_item_id,
  v.code,
  v.idx
FROM (VALUES
  (0, 'SF016'),   -- Alaskan Pollock     Gadus chalcogrammus
  (1, 'SF019'),   -- Atlantic Cod        Gadus Morhua
  (2, 'SF020'),   -- Atlantic Salmon     Salmo salar
  (3, 'SF002'),   -- Bawal Hitam         Parastromateus niger
  (4, 'SF007'),   -- Cencaru             Megalaspis cordyla
  (5, 'SF003'),   -- Ikan Merah          Lutjanus sebae
  (6, 'SF008'),   -- Jenahak             Lutjanus johnii
  (7, 'SF001'),   -- Kembung / Pelaling  Rastrelliger kanagurta
  (8, 'SF005'),   -- Kerapu Bintik       Epinephelus coioides
  (9, 'SF037'),   -- Kerapu Harimau      Epinephelus fuscoguttatus
  (10, 'SF038'),   -- Kerapu Kertang      Epinephelus lanceolatus
  (11, 'SF039'),   -- Kerapu Lumpur       Epinephelus malabaricus
  (12, 'SF041'),   -- Kerapu Tikus        Cromileptes altivelis
  (13, 'SF044'),   -- Kunyit-kunyit       Lutjanus vitta
  (14, 'SF046'),   -- Mameng              Cheilinus undulatus
  (15, 'SF051'),   -- Siakap Merah        Lutjanus argentimaculatus
  (16, 'SF014'),   -- Siakap Putih        Lates calcarifer
  (17, 'SF012'),   -- Tenggiri            Scomberomorus commerson
  (18, 'SF004')   -- Tilapia             Oreochromis Niloticus
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
  -- actually landed rather than trusting the INSERT to have run 19 times.
  SELECT count(*) INTO n_mappings
    FROM cv_class_mapping m
    JOIN cv_model_version v USING (cv_model_version_id)
   WHERE v.active;
  IF n_mappings <> 19 THEN
    RAISE EXCEPTION 'active model has % class mappings, expected 19 -- a seafood_item code in the class map does not exist', n_mappings;
  END IF;

  -- Model class indices must address 0..N-1 exactly, because the adapter
  -- looks up the argmax of the output vector by position.
  SELECT count(DISTINCT m.model_class_index) INTO n_joined
    FROM cv_class_mapping m
    JOIN cv_model_version v USING (cv_model_version_id)
   WHERE v.active AND m.model_class_index BETWEEN 0 AND 18;
  IF n_joined <> 19 THEN
    RAISE EXCEPTION 'class indices are not a complete 0..18 set';
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
