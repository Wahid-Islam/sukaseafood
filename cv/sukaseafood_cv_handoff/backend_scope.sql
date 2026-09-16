-- Apply with 19_cv_i2_19class.sql on an existing database.
-- class_index is frozen in model.onnx; class_code is the 54-fish catalogue id.
-- CUTOVER: drain traffic and snapshot supports_cv first. This transaction and
-- the generated registration transaction in seed 19 are one unit; restore the
-- supports_cv snapshot immediately if registration fails.
BEGIN;
UPDATE seafood_item
   SET supports_cv = code IN (
         'SF001', 'SF002', 'SF003', 'SF004', 'SF005',
         'SF007', 'SF008', 'SF012', 'SF014', 'SF016',
         'SF019', 'SF020', 'SF037', 'SF038', 'SF039',
         'SF041', 'SF044', 'SF046', 'SF051'
       ),
       updated_at = now();
COMMIT;
