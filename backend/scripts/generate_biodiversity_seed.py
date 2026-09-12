"""Turn retrieved FishBase / GBIF / OBIS facts into an idempotent SQL seed."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PARSED = ROOT / "data" / "biodiversity_parsed.json"
OUT = ROOT / "backend" / "db" / "seed" / "15_biodiversity.sql"

IUCN_LABELS = {
    "LC": "Least Concern",
    "NT": "Near Threatened",
    "VU": "Vulnerable",
    "EN": "Endangered",
    "CR": "Critically Endangered",
    "DD": "Data Deficient",
    "NE": "Not Evaluated",
}


def sql_str(value: str | None) -> str:
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def sql_num(value: float | None) -> str:
    if value is None:
        return "NULL"
    return str(value)


def clean_biology(text: str | None) -> str | None:
    if not text:
        return None
    text = re.sub(r"^Glossary \(e\.g\. epibenthic\)\s*", "", text)
    text = re.sub(r"\s*\(Ref\.\s*\d+\s*\)\s*", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text or None


def ecological_role(text: str | None) -> str | None:
    """Keep FishBase diet/role sentences; drop market and glossary leftovers."""
    cleaned = clean_biology(text)
    if not cleaned:
        return None
    sentences = [s.strip() for s in re.split(r"(?<=[.])\s+", cleaned) if s.strip()]
    diet = [
        s
        for s in sentences
        if re.search(
            r"\b(feed|feeds|diet|prey|trophic|plankton|predatory|predator|"
            r"forage|eats|eating)\b",
            s,
            re.I,
        )
    ]
    picked = diet[:2] if diet else sentences[:2]
    out = " ".join(picked).strip()
    if len(out) > 420 and picked:
        out = picked[0]
    return out or None


def iucn_row(item: dict) -> tuple[str | None, str | None, str | None]:
    iucn = item.get("iucn") or {}
    page = (item.get("fishbase") or {}).get("iucn_page") or {}
    code = iucn.get("code") or page.get("code")
    if not code:
        return None, None, None
    code = str(code).upper()
    label = IUCN_LABELS.get(code)
    if not label:
        raw = iucn.get("label")
        label = raw.replace("_", " ").title() if raw else code
    sci = item.get("scientific_name") or ""
    url = (
        f"https://www.iucnredlist.org/search?query={sci.replace(' ', '%20')}"
        if sci
        else None
    )
    return code, label, url


def main() -> None:
    items = json.loads(PARSED.read_text(encoding="utf-8"))
    profile_values = []
    occ_values = []
    for item in items:
        code = item["code"]
        fb = item.get("fishbase") or {}
        role = ecological_role(fb.get("biology"))
        iucn_code, iucn_label, iucn_url = iucn_row(item)
        profile_values.append(
            "("
            + ", ".join(
                [
                    f"suka_uuid5('seafood_item:{code}')",
                    sql_str(fb.get("habitat")),
                    sql_num(fb.get("depth_shallow_m")),
                    sql_num(fb.get("depth_deep_m")),
                    sql_str(role),
                    sql_str(iucn_code),
                    sql_str(iucn_label),
                    sql_str(iucn_url),
                    sql_str(fb.get("url")),
                    "TIMESTAMPTZ '2026-09-12 13:20:00+00'",
                    "suka_uuid5('source_snapshot:fishbase:2026-09-12')",
                ]
            )
            + ")"
        )
        points = ((item.get("obis") or {}).get("points")) or []
        seen = set()
        kept = 0
        for point in points:
            lat = point.get("lat")
            lon = point.get("lon")
            if lat is None or lon is None:
                continue
            key = (round(float(lat), 4), round(float(lon), 4))
            if key in seen:
                continue
            seen.add(key)
            kept += 1
            if kept > 40:
                break
            date = point.get("event_date")
            date_sql = "NULL"
            if date:
                raw = str(date)[:10]
                if re.fullmatch(r"\d{4}-\d{2}-\d{2}", raw):
                    date_sql = sql_str(raw)
            occ_values.append(
                "("
                + ", ".join(
                    [
                        f"suka_uuid5('bio_occ:{code}:{key[0]}:{key[1]}')",
                        f"suka_uuid5('seafood_item:{code}')",
                        str(float(lat)),
                        str(float(lon)),
                        sql_str(point.get("country")),
                        sql_str(point.get("locality")),
                        date_sql,
                    ]
                )
                + ")"
            )

    sql = f"""-- Retrieved 2026-09-12 from FishBase summary pages, GBIF IUCN
-- categories, and OBIS occurrence records. Missing fields stay NULL.

BEGIN;

INSERT INTO data_source (data_source_id, source_key, name, owner, type, homepage_url, license, active)
SELECT
  suka_uuid5('data_source:' || v.source_key),
  v.source_key, v.name, v.owner, v.type, v.homepage_url, v.license, TRUE
FROM (VALUES
  ('fishbase', 'FishBase', 'Froese & Pauly / FishBase', 'BIODIVERSITY',
   'https://www.fishbase.se', 'FishBase citation required.'),
  ('obis', 'OBIS', 'Ocean Biodiversity Information System', 'BIODIVERSITY',
   'https://obis.org', 'Mostly CC BY 4.0; verify per-dataset licence.'),
  ('iucn_redlist', 'IUCN Red List of Threatened Species', 'IUCN', 'BIODIVERSITY',
   'https://www.iucnredlist.org', 'IUCN Red List categories via GBIF/FishBase.'),
  ('mybis', 'MyBIS', 'Malaysia Biodiversity Information System', 'BIODIVERSITY',
   'https://www.mybis.gov.my', 'No public API on file. National status stays unavailable.'),
  ('reef_check', 'Reef Check', 'Reef Check Malaysia / Reef Check', 'BIODIVERSITY',
   'https://www.reefcheck.org.my', 'No public machine-readable extract on file.')
) AS v(source_key, name, owner, type, homepage_url, license)
ON CONFLICT (data_source_id) DO UPDATE SET
  name = EXCLUDED.name,
  homepage_url = EXCLUDED.homepage_url,
  license = EXCLUDED.license,
  active = EXCLUDED.active;

INSERT INTO source_snapshot (
  source_snapshot_id, data_source_id, version_label,
  source_period_start, source_period_end, retrieved_at, collection_method, manifest, notes
)
SELECT
  suka_uuid5('source_snapshot:' || v.source_key || ':' || v.version_label),
  suka_uuid5('data_source:' || v.source_key),
  v.version_label, NULL, NULL, TIMESTAMPTZ '2026-09-12 13:20:00+00',
  'OFFICIAL_DOWNLOAD'::collection_method_enum,
  '{{"tables":["species","occurrence"]}}'::jsonb,
  v.notes
FROM (VALUES
  ('fishbase', '2026-09-12', 'FishBase summary pages retrieved 2026-09-12.'),
  ('obis', '2026-09-12', 'OBIS API v3 occurrence sample, up to 40 points per species.'),
  ('iucn_redlist', '2026-09-12', 'IUCN category via GBIF species match.')
) AS v(source_key, version_label, notes)
ON CONFLICT (source_snapshot_id) DO UPDATE SET
  notes = EXCLUDED.notes,
  retrieved_at = EXCLUDED.retrieved_at;

INSERT INTO biodiversity_profile (
  seafood_item_id, habitat_group, depth_shallow_m, depth_deep_m,
  ecological_role, iucn_category, iucn_label, iucn_url, fishbase_url,
  retrieved_at, source_snapshot_id
)
SELECT
  v.seafood_item_id, v.habitat_group, v.depth_shallow_m, v.depth_deep_m,
  v.ecological_role, v.iucn_category, v.iucn_label, v.iucn_url, v.fishbase_url,
  v.retrieved_at, v.source_snapshot_id
FROM (VALUES
  {",\\n  ".join(profile_values)}
) AS v(
  seafood_item_id, habitat_group, depth_shallow_m, depth_deep_m,
  ecological_role, iucn_category, iucn_label, iucn_url, fishbase_url,
  retrieved_at, source_snapshot_id
)
WHERE EXISTS (SELECT 1 FROM seafood_item s WHERE s.seafood_item_id = v.seafood_item_id)
ON CONFLICT (seafood_item_id) DO UPDATE SET
  habitat_group = EXCLUDED.habitat_group,
  depth_shallow_m = EXCLUDED.depth_shallow_m,
  depth_deep_m = EXCLUDED.depth_deep_m,
  ecological_role = EXCLUDED.ecological_role,
  iucn_category = EXCLUDED.iucn_category,
  iucn_label = EXCLUDED.iucn_label,
  iucn_url = EXCLUDED.iucn_url,
  fishbase_url = EXCLUDED.fishbase_url,
  retrieved_at = EXCLUDED.retrieved_at,
  source_snapshot_id = EXCLUDED.source_snapshot_id;

DELETE FROM biodiversity_occurrence
 WHERE seafood_item_id IN (SELECT seafood_item_id FROM biodiversity_profile);

INSERT INTO biodiversity_occurrence (
  occurrence_id, seafood_item_id, latitude, longitude, country, locality, event_date
)
SELECT
  v.occurrence_id, v.seafood_item_id, v.latitude, v.longitude,
  v.country, v.locality, v.event_date::date
FROM (VALUES
  {",\\n  ".join(occ_values)}
) AS v(occurrence_id, seafood_item_id, latitude, longitude, country, locality, event_date)
WHERE EXISTS (SELECT 1 FROM seafood_item s WHERE s.seafood_item_id = v.seafood_item_id)
ON CONFLICT (occurrence_id) DO UPDATE SET
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  country = EXCLUDED.country,
  locality = EXCLUDED.locality,
  event_date = EXCLUDED.event_date;

COMMIT;
"""
    OUT.write_text(sql.replace("\\n", "\n"), encoding="utf-8")
    print(f"wrote {OUT} profiles={len(profile_values)} occurrences={len(occ_values)}")


if __name__ == "__main__":
    main()
