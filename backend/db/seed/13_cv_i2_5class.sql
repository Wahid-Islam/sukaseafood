-- =========================================================
-- 13_cv_i2_5class.sql
-- =========================================================
-- Iteration 2 scanner: five trained species only.
-- Apply this on an existing database before (or with) the regenerated
-- 06_cv_model_registration.sql. Idempotent.
--
-- Scannable: SF001 Kembung, SF002 Bawal Hitam, SF007 Cencaru,
--            SF008 Jenahak, SF012 Tenggiri.

BEGIN;

UPDATE seafood_item
   SET supports_cv = code IN ('SF001', 'SF002', 'SF007', 'SF008', 'SF012'),
       updated_at = now()
 WHERE code IN ('SF001', 'SF002', 'SF003', 'SF004', 'SF005', 'SF006',
                'SF007', 'SF008', 'SF009', 'SF010', 'SF011', 'SF012');

DO $$
DECLARE
  n_cv INT;
BEGIN
  SELECT count(*) INTO n_cv FROM seafood_item WHERE supports_cv;
  IF n_cv <> 5 THEN
    RAISE EXCEPTION 'expected 5 CV-supported species after I2 cutover, found %', n_cv;
  END IF;
END $$;

COMMIT;
