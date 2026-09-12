-- Biodiversity context retrieved from FishBase, OBIS and IUCN/GBIF.
-- Missing values stay NULL. Do not invent habitat, depth, IUCN or points.

CREATE TABLE IF NOT EXISTS biodiversity_profile (
  seafood_item_id UUID PRIMARY KEY
    REFERENCES seafood_item(seafood_item_id) ON DELETE RESTRICT,
  habitat_group TEXT,
  depth_shallow_m NUMERIC,
  depth_deep_m NUMERIC,
  ecological_role TEXT,
  iucn_category TEXT,
  iucn_label TEXT,
  iucn_url TEXT,
  fishbase_url TEXT,
  retrieved_at TIMESTAMPTZ NOT NULL,
  source_snapshot_id UUID REFERENCES source_snapshot(source_snapshot_id)
);

CREATE TABLE IF NOT EXISTS biodiversity_occurrence (
  occurrence_id UUID PRIMARY KEY,
  seafood_item_id UUID NOT NULL
    REFERENCES seafood_item(seafood_item_id) ON DELETE RESTRICT,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  country TEXT,
  locality TEXT,
  event_date DATE
);

CREATE INDEX IF NOT EXISTS idx_biodiversity_occurrence_item
  ON biodiversity_occurrence (seafood_item_id);
