#!/usr/bin/env python3
"""Turn the enriched WWF SOS CSV into db/seed/11_wwf_sos_2022.sql.

    cd backend && python scripts/generate_wwf_context_seed.py

Every Malaysian WWF row that maps to a catalogue species is written, including
species with two gear ratings (Tenggiri Reduce / Avoid). The API returns those
as separate assessments so the profile can show both. Demuduk is not in the
public WWF guide, so it is also omitted.
"""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CSV_PATH = ROOT / "data" / "wwf_save_our_seafood_2022_backend_enriched_latest.csv"
OUT_PATH = ROOT / "backend" / "db" / "seed" / "11_wwf_sos_2022.sql"

SNAPSHOT = "wwf-sos-2022-enriched-latest"
RATING_MAP = {
    "best choice": "BEST_CHOICE",
    "reduce": "REDUCE",
    "avoid": "AVOID",
}

# How each catalogue fish is matched to a WWF row. Scientific names are
# normalised (lower, stripped). Common-name matches are used only when the
# WWF binomial and the catalogue binomial are known to disagree, and the
# assessment keeps WWF's own scientific_name_raw.
#
# skip_origin_contains: drop the certified Hulu Perak tilapia Best Choice so
# unlabelled market tilapia is not shown as that special case.
SPECIES: dict[str, dict[str, str]] = {
    "SF001": {"scientific": "rastrelliger kanagurta"},
    "SF002": {"scientific": "parastromateus niger"},
    "SF003": {"scientific": "lutjanus sebae"},
    "SF004": {
        "scientific": "oreochromis niloticus",
        "skip_origin_contains": "hulu perak",
    },
    "SF005": {"scientific": "epinephelus coioides"},
    "SF006": {"common": "bawal putih"},
    "SF007": {"scientific": "megalaspis cordyla"},
    "SF008": {"scientific": "lutjanus johnii"},
    "SF009": {"common": "kerisi"},
    "SF010": {"scientific": "alepes melanoptera"},
    "SF011": {"scientific": "selaroides leptolepis"},
    "SF012": {"scientific": "scomberomorus commerson"},
    "SF014": {"scientific": "lates calcarifer"},
}

TYPOS = {"nemipterus japiconus": "nemipterus japonicus"}


def sql_str(value: str | None) -> str:
    if value is None or not str(value).strip() or str(value).strip() == "-":
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def norm_sci(value: str) -> str:
    cleaned = re.sub(r"\s+", " ", value.strip().lower())
    return TYPOS.get(cleaned, cleaned)


def malaysia(row: dict[str, str]) -> bool:
    return "malaysia" in (row.get("origin") or "").lower()


def production_type(method: str) -> str:
    lowered = method.lower()
    if "farmed" in lowered or "cage" in lowered or "pond" in lowered:
        return "FARMED"
    return "WILD"


def method_code(method: str) -> str:
    lowered = method.lower()
    if "purse" in lowered:
        return "PURSE_SEINE"
    if "trawl" in lowered:
        return "TRAWL"
    if "gill" in lowered:
        return "GILLNET"
    if "hook" in lowered or "line" in lowered:
        return "HOOK_AND_LINE"
    if "cage" in lowered or "pond" in lowered or "farmed" in lowered:
        return "AQUACULTURE"
    return "OTHER"


def load_rows() -> list[dict[str, str]]:
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        raw_rows = list(csv.DictReader(handle))
    cleaned: list[dict[str, str]] = []
    for row in raw_rows:
        normalised = {
            (key or "").lstrip("\ufeff").strip(): (value if value is not None else "")
            for key, value in row.items()
            if key is not None
        }
        cleaned.append(normalised)
    return cleaned


def match_rows(code: str, rows: list[dict[str, str]]) -> list[dict[str, str]]:
    spec = SPECIES[code]
    skip = (spec.get("skip_origin_contains") or "").lower()
    matched: list[dict[str, str]] = []
    for row in rows:
        if not malaysia(row):
            continue
        origin = (row.get("origin") or "").lower()
        if skip and skip in origin:
            continue
        if "scientific" in spec:
            if norm_sci(row.get("scientific_name") or "") != spec["scientific"]:
                continue
        elif "common" in spec:
            if (row.get("main_common_name") or "").strip().lower() != spec["common"]:
                continue
        else:
            continue
        matched.append(row)
    return matched


def pick_rows(code: str, rows: list[dict[str, str]]) -> list[dict[str, str]]:
    matched = match_rows(code, rows)
    if not matched:
        print(f"  {code}: no Malaysian WWF row — skipped", file=sys.stderr)
        return []
    for row in matched:
        print(
            f"  {code}: {row['sustainability_rating']} "
            f"({row['origin']}; {row['production_method_final']})",
            file=sys.stderr,
        )
    return matched


def render(rows: list[tuple[str, dict[str, str]]]) -> str:
    value_sql = []
    for code, row in rows:
        rating = RATING_MAP[row["sustainability_rating"].strip().lower()]
        method = row.get("production_method_final") or ""
        origin = (row.get("origin") or "").strip()
        if origin.endswith("&") or origin.endswith("&,"):
            origin = "Malaysia (East Coast)"
        value_sql.append(
            "  ("
            + ", ".join(
                [
                    sql_str(code),
                    sql_str(f"wwf-row-{row['wwf_row_id']}"),
                    sql_str(row.get("main_common_name")),
                    sql_str(row.get("secondary_common_name")),
                    sql_str(row.get("scientific_name")),
                    sql_str(rating),
                    sql_str(origin),
                    sql_str("MY"),
                    sql_str(production_type(method)),
                    sql_str(method),
                    sql_str(method_code(method)),
                    sql_str(row.get("certification") or None),
                    sql_str(row.get("context")),
                    sql_str(row.get("description")),
                ]
            )
            + ")"
        )
    values = ",\n".join(value_sql)
    return f"""-- =========================================================
-- 11_wwf_sos_2022.sql   ** GENERATED FILE — DO NOT EDIT **
-- =========================================================
-- Regenerate with:  cd backend && python scripts/generate_wwf_context_seed.py
--
-- Source: data/wwf_save_our_seafood_2022_backend_enriched_latest.csv
-- A newer snapshot than wwf-sos-2026-handoff, so GET /seafood picks these
-- rows (most recent retrieved_at) without rewriting the original transcription.

BEGIN;

INSERT INTO source_snapshot (
  source_snapshot_id, data_source_id, version_label,
  source_period_start, source_period_end, retrieved_at, collection_method, manifest, notes
)
SELECT
  suka_uuid5('source_snapshot:wwf_sos:{SNAPSHOT}'),
  suka_uuid5('data_source:wwf_sos'),
  '{SNAPSHOT}',
  '2022-01-01'::date,
  '2022-12-31'::date,
  '2026-09-02T00:00:00+08:00'::timestamptz,
  'MANUAL_PDF_TRANSCRIPTION'::collection_method_enum,
  '{{"files": ["wwf_save_our_seafood_2022_backend_enriched_latest.csv"]}}'::jsonb,
  'Enriched WWF Save Our Seafood 2022 rows, including per-listing context copy.'
ON CONFLICT (source_snapshot_id) DO UPDATE SET
  retrieved_at = EXCLUDED.retrieved_at,
  manifest     = EXCLUDED.manifest,
  notes        = EXCLUDED.notes;

INSERT INTO wwf_assessment (
  wwf_assessment_id, seafood_item_id, source_snapshot_id, source_record_key,
  common_name_raw, secondary_common_name_raw, scientific_name_raw, rating,
  origin_raw, origin_code, production_type, production_method_raw,
  production_method_code, certification_raw, context, notes_raw
)
SELECT
  suka_uuid5('wwf_assessment:{SNAPSHOT}:' || v.source_record_key),
  suka_uuid5('seafood_item:' || v.code),
  suka_uuid5('source_snapshot:wwf_sos:{SNAPSHOT}'),
  v.source_record_key,
  v.common_name_raw, v.secondary_common_name_raw, v.scientific_name_raw,
  v.rating::sustainability_rating_enum,
  v.origin_raw, v.origin_code, v.production_type, v.production_method_raw,
  v.production_method_code, v.certification_raw, v.context, v.notes_raw
FROM (VALUES
{values}
) AS v(code, source_record_key, common_name_raw, secondary_common_name_raw,
       scientific_name_raw, rating, origin_raw, origin_code, production_type,
       production_method_raw, production_method_code, certification_raw,
       context, notes_raw)
ON CONFLICT (wwf_assessment_id) DO UPDATE SET
  rating                     = EXCLUDED.rating,
  common_name_raw            = EXCLUDED.common_name_raw,
  secondary_common_name_raw  = EXCLUDED.secondary_common_name_raw,
  scientific_name_raw        = EXCLUDED.scientific_name_raw,
  origin_raw                 = EXCLUDED.origin_raw,
  origin_code                = EXCLUDED.origin_code,
  production_type            = EXCLUDED.production_type,
  production_method_raw      = EXCLUDED.production_method_raw,
  production_method_code     = EXCLUDED.production_method_code,
  certification_raw          = EXCLUDED.certification_raw,
  context                    = EXCLUDED.context,
  notes_raw                  = EXCLUDED.notes_raw;

COMMIT;
"""


def main() -> int:
    if not CSV_PATH.is_file():
        print(f"missing {CSV_PATH}", file=sys.stderr)
        return 1
    print("Matching catalogue species to WWF SOS 2022 rows:", file=sys.stderr)
    source = load_rows()
    picked: list[tuple[str, dict[str, str]]] = []
    for code in SPECIES:
        picked.extend((code, row) for row in pick_rows(code, source))
    OUT_PATH.write_text(render(picked), encoding="utf-8")
    print(f"Wrote {len(picked)} assessments to {OUT_PATH}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
