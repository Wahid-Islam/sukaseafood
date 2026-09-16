-- =========================================================
-- 17_deactivate_demuduk.sql
-- =========================================================
-- Hide SF013 Demuduk / Cupak / Cermin from the public catalogue.
--
-- Why the row still exists
-- ------------------------
-- SF013 is a family-level PriceCatcher key (item 1916) that the R forecast
-- engine already emits. Deleting it would orphan aliases, observed prices,
-- forecasts and any saved favourites. The public WWF 54-fish list does not
-- include it; Kikek (SF043, Leiognathus spp.) is the WWF ponyfish listing.
--
-- Runs after 08 (which inserts the row) and 10_wwf_catalogue_54.sql (which
-- does not mention SF013). Idempotent.

BEGIN;

UPDATE seafood_item
   SET active = FALSE,
       updated_at = now()
 WHERE code = 'SF013'
   AND active IS DISTINCT FROM FALSE;

COMMIT;
