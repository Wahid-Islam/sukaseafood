-- Move the retrieved Euthynnus affinis biodiversity extract off SF015.
-- WWF now lists SF015 Tongkol as Thunnus tonggol; Kawakawa is SF054.
-- Idempotent: 15_biodiversity.sql may re-attach the extract to SF015.

BEGIN;

UPDATE biodiversity_occurrence
SET seafood_item_id = suka_uuid5('seafood_item:SF054')
WHERE seafood_item_id = suka_uuid5('seafood_item:SF015');

DELETE FROM biodiversity_profile
WHERE seafood_item_id = suka_uuid5('seafood_item:SF015')
  AND EXISTS (
    SELECT 1
    FROM biodiversity_profile existing
    WHERE existing.seafood_item_id = suka_uuid5('seafood_item:SF054')
  );

UPDATE biodiversity_profile
SET seafood_item_id = suka_uuid5('seafood_item:SF054')
WHERE seafood_item_id = suka_uuid5('seafood_item:SF015');

DELETE FROM seafood_alias
WHERE seafood_item_id = suka_uuid5('seafood_item:SF015')
  AND lower(trim(alias_name)) IN ('kawakawa', 'euthynnus affinis');

COMMIT;
