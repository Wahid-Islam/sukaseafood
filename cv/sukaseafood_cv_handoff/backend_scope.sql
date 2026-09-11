-- Apply before registering cv-i1-5class-20260902T174905Z-36ac9b6a-a53adadffa11 on an existing database.
-- fish_id is SFxxx; seafood_item_id remains the canonical UUID owned by PostgreSQL.
-- CUTOVER: drain traffic and snapshot supports_cv first. This transaction and the
-- generated registration transaction are separate and are not atomic; restore the
-- supports_cv snapshot immediately if registration fails.
BEGIN;
UPDATE seafood_item
   SET supports_cv = code IN ('SF001', 'SF002', 'SF007', 'SF008', 'SF012'), updated_at = now()
 WHERE code IN ('SF001', 'SF002', 'SF003', 'SF004', 'SF005', 'SF006', 'SF007', 'SF008', 'SF009', 'SF010', 'SF011', 'SF012');
COMMIT;

-- Then run, from the original repository's cv/ directory:
-- python -X utf8 scripts/register_model.py --handoff <this-handoff-directory>
-- Apply its generated backend/db/seed/06_cv_model_registration.sql and restart the API.
-- For fresh DB builds, seed 05 must also set SF003/SF004/SF005/SF006/SF009/SF010/SF011 FALSE
-- (not merely change its 9-to-5 assertion); keep only the five selected codes TRUE.
-- Change seed 05 and seed 08 CV-count guards/comments from 9 to 5, regenerate seed 06,
-- then verify the active map and supports_cv set are exactly these five codes.
