-- =========================================================
-- v3_user_prefs.sql — account favourites and forecast location
-- =========================================================
-- Additive. Domain seafood data stays on seafood_item; this only records
-- which species an app_user saved and which location their forecasts use.
--
-- preferred_location_id is nullable. NULL means "use the engine default
-- (Selangor state)", which is the production forecast scope. The profile
-- must display that resolved name rather than a hardcoded city.
--
-- Idempotent: safe to re-run via apply.sh.

BEGIN;

ALTER TABLE app_user
  ADD COLUMN IF NOT EXISTS preferred_location_id UUID
    REFERENCES location(location_id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS user_favourite (
  app_user_id UUID NOT NULL
    REFERENCES app_user(id) ON DELETE CASCADE,
  seafood_item_id UUID NOT NULL
    REFERENCES seafood_item(seafood_item_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (app_user_id, seafood_item_id)
);

CREATE INDEX IF NOT EXISTS user_favourite_user_idx
  ON user_favourite (app_user_id, created_at DESC);

COMMIT;
