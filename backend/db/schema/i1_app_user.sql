-- App accounts (email/password). Domain seafood schema stays in i1_initial_schema.sql.
-- Idempotent: safe to re-run via apply.sh.

BEGIN;

CREATE TABLE IF NOT EXISTS app_user (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  email         text NOT NULL,
  password_hash text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT app_user_email_nonempty CHECK (length(trim(email)) > 0),
  CONSTRAINT app_user_name_nonempty CHECK (length(trim(name)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS app_user_email_uidx
  ON app_user (lower(trim(email)));

COMMIT;
