-- Canonical species photographs (Wikimedia Commons FilePath).
--
-- Production Firebase Storage objects at seafood/SF00x.jpg all 404'd. The
-- API was emitting those URLs as a derived fallback whenever
-- primary_image_url was null, so every catalogue card showed a broken image.
--
-- PostgreSQL remains the system of record: the URL is a column on
-- seafood_item, not a Firestore document. Commons FilePath is used because
-- the files are already public-domain / CC species photographs of the named
-- fish, which is what the Flutter client already loaded in the prototype.
-- Replacing a photo is an UPDATE, never a code change.
--
-- Idempotent: safe to re-run.

BEGIN;

UPDATE seafood_item AS s
SET primary_image_url = v.url,
    updated_at = now()
FROM (VALUES
  ('SF001', 'https://commons.wikimedia.org/wiki/Special:FilePath/Rastrelliger_kanagurta_JNC2855.JPG?width=800'),
  ('SF002', 'https://commons.wikimedia.org/wiki/Special:FilePath/Parastromateus_niger.jpg?width=800'),
  ('SF003', 'https://commons.wikimedia.org/wiki/Special:FilePath/Lutjanus_sebae_in_UShaka_Sea_World_0862a.jpg?width=800'),
  ('SF004', 'https://commons.wikimedia.org/wiki/Special:FilePath/Til%C3%A1pia_ou_Sarotherodon_niloticus_2.jpg?width=800'),
  ('SF005', 'https://commons.wikimedia.org/wiki/Special:FilePath/Epinephelus_coioides.jpg?width=800'),
  ('SF006', 'https://commons.wikimedia.org/wiki/Special:FilePath/Pampus_argenteus.jpg?width=800'),
  ('SF007', 'https://commons.wikimedia.org/wiki/Special:FilePath/Megalaspis_cordyla.jpg?width=800'),
  ('SF008', 'https://commons.wikimedia.org/wiki/Special:FilePath/Lutjanus_johnii.jpg?width=800'),
  ('SF009', 'https://commons.wikimedia.org/wiki/Special:FilePath/Nemipterus_japonicus.jpg?width=800'),
  ('SF010', 'https://commons.wikimedia.org/wiki/Special:FilePath/Alepes_melanoptera.jpg?width=800'),
  ('SF011', 'https://commons.wikimedia.org/wiki/Special:FilePath/Yellowstripe%20Cads%20(Selaroides%20leptolepis)%20(8460533635).jpg?width=800'),
  ('SF012', 'https://commons.wikimedia.org/wiki/Special:FilePath/Narrow-barred%20spanish%20mackerel%20(Scomberomorus%20commerson).jpg?width=800'),
  ('SF013', 'https://commons.wikimedia.org/wiki/Special:FilePath/Photo%20of%20ponyfish.jpg?width=800'),
  ('SF014', 'https://commons.wikimedia.org/wiki/Special:FilePath/Lates_calcarifer,_2014-09-19a.jpg?width=800')
) AS v(code, url)
WHERE s.code = v.code;

COMMIT;
