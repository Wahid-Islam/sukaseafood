#!/usr/bin/env python3
"""Build cooking suitability for the 54 WWF-listed fishes.

    cd backend && python scripts/generate_cooking_54.py

Maps CSV `fish_name` onto `data/wwf_catalogue_54_ids.json` codes. CSV UUIDs
are ignored — they are not the `suka_uuid5` keys the rest of the database uses.
"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CSV_PATH = ROOT / "data" / "SuitabilityScoreSuka_complete_54_fish.csv"
IDS_PATH = ROOT / "data" / "wwf_catalogue_54_ids.json"
OUT_PATH = ROOT / "backend" / "db" / "seed" / "18_cooking_54.sql"

SNAPSHOT = "cooking-54-20260914"
METHOD_ORDER = ("GRILL", "STEAM", "FRY", "CURRY", "SOUP", "BAKE", "RAW")


def sql_str(value: str | None) -> str:
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def load_codes() -> dict[str, str]:
    payload = json.loads(IDS_PATH.read_text(encoding="utf-8"))
    codes = payload["codes"]
    if len(codes) != 54:
        raise SystemExit(f"expected 54 catalogue codes, got {len(codes)}")
    return codes


def load_rows(codes: dict[str, str]) -> list[tuple[str, str, int, str, str]]:
    raw = list(CSV_PATH.open(encoding="utf-8-sig"))
    rows = list(csv.DictReader(raw))
    names = {row["fish_name"].strip() for row in rows}
    missing = sorted(names - set(codes))
    extra = sorted(set(codes) - names)
    if missing or extra:
        raise SystemExit(
            "cooking CSV names do not match the WWF 54-fish list: "
            f"csv-only={missing} catalogue-only={extra}"
        )
    if any("demud" in name.lower() for name in names):
        raise SystemExit("Demuduk is not a WWF-listed fish and must not appear in the cooking CSV")

    out: list[tuple[str, str, int, str, str]] = []
    seen: set[tuple[str, str]] = set()
    for row in rows:
        name = row["fish_name"].strip()
        method = row["cooking_method_code"].strip().upper()
        if method not in METHOD_ORDER:
            raise SystemExit(f"unknown cooking method {method!r} for {name}")
        key = (codes[name], method)
        if key in seen:
            raise SystemExit(f"duplicate cooking row {key}")
        seen.add(key)
        out.append(
            (
                codes[name],
                method,
                int(row["suitability_score"]),
                row["reason_en"],
                row["reason_ms"],
            )
        )
    expected = {(code, method) for code in codes.values() for method in METHOD_ORDER}
    if seen != expected:
        raise SystemExit(
            f"expected {len(expected)} cooking rows (54 x 7), got {len(seen)}"
        )
    rank = {method: i for i, method in enumerate(METHOD_ORDER)}
    out.sort(key=lambda item: (item[0], rank[item[1]]))
    return out


def render(rows: list[tuple[str, str, int, str, str]]) -> str:
    values = ",\n".join(
        "  ("
        + ", ".join(
            [
                sql_str(code),
                sql_str(method),
                str(score),
                sql_str(reason_en),
                sql_str(reason_ms),
            ]
        )
        + ")"
        for code, method, score, reason_en, reason_ms in rows
    )
    return f"""-- =========================================================
-- 18_cooking_54.sql   ** GENERATED FILE — DO NOT EDIT **
-- =========================================================
-- Regenerate with:  cd backend && python scripts/generate_cooking_54.py
-- Source: data/SuitabilityScoreSuka_complete_54_fish.csv
-- 54 WWF-listed fishes x 7 methods. Mapped by fish_name; CSV UUIDs unused.
-- SF013 Demuduk is not in this file.

BEGIN;

INSERT INTO source_snapshot (
  source_snapshot_id, data_source_id, version_label,
  retrieved_at, collection_method, manifest, notes
) VALUES (
  suka_uuid5('source_snapshot:team_curated:{SNAPSHOT}'),
  suka_uuid5('data_source:team_curated'),
  '{SNAPSHOT}',
  TIMESTAMPTZ '2026-09-14 00:00:00+00',
  'TEAM_CURATED',
  '{{"files": ["SuitabilityScoreSuka_complete_54_fish.csv"]}}'::jsonb,
  'Cooking suitability for the 54 WWF-listed fishes. Scores and reasons '
  'come from the retrieved CSV, keyed onto suka_uuid5 seafood_item and '
  'cooking_method ids. CSV UUIDs are not used.'
)
ON CONFLICT (source_snapshot_id) DO UPDATE SET
  version_label = EXCLUDED.version_label,
  retrieved_at  = EXCLUDED.retrieved_at,
  notes         = EXCLUDED.notes,
  manifest      = EXCLUDED.manifest;

INSERT INTO cooking_suitability (
  cooking_suitability_id, seafood_item_id, cooking_method_id, source_snapshot_id,
  suitability_score, reason_en, reason_ms, updated_at
)
SELECT
  suka_uuid5('cooking_suitability:' || v.code || ':' || v.method),
  suka_uuid5('seafood_item:' || v.code),
  suka_uuid5('cooking_method:' || v.method),
  suka_uuid5('source_snapshot:team_curated:{SNAPSHOT}'),
  v.score::smallint,
  v.reason_en,
  v.reason_ms,
  TIMESTAMPTZ '2026-09-14 00:00:00+00'
FROM (VALUES
{values}
) AS v(code, method, score, reason_en, reason_ms)
ON CONFLICT (cooking_suitability_id) DO UPDATE SET
  suitability_score = EXCLUDED.suitability_score,
  reason_en         = EXCLUDED.reason_en,
  reason_ms         = EXCLUDED.reason_ms,
  source_snapshot_id = EXCLUDED.source_snapshot_id,
  updated_at        = EXCLUDED.updated_at;

DO $$
DECLARE
  n_rows INT;
  n_missing INT;
BEGIN
  SELECT count(*) INTO n_rows
    FROM cooking_suitability c
    JOIN seafood_item s USING (seafood_item_id)
    JOIN source_snapshot snap ON snap.source_snapshot_id = c.source_snapshot_id
   WHERE snap.version_label = '{SNAPSHOT}';
  IF n_rows <> 378 THEN
    RAISE EXCEPTION 'expected 378 cooking rows for the 54 WWF fishes, found %', n_rows;
  END IF;

  SELECT count(*) INTO n_missing
    FROM seafood_item s
   WHERE s.active
     AND s.code <> 'SF013'
     AND NOT EXISTS (
           SELECT 1 FROM cooking_suitability c
            WHERE c.seafood_item_id = s.seafood_item_id
         );
  IF n_missing > 0 THEN
    RAISE EXCEPTION '% active species have no cooking_suitability rows', n_missing;
  END IF;
END $$;

COMMIT;
"""


def main() -> int:
    if not CSV_PATH.is_file():
        print(f"missing {CSV_PATH}", file=sys.stderr)
        return 1
    if not IDS_PATH.is_file():
        print(f"missing {IDS_PATH}", file=sys.stderr)
        return 1
    codes = load_codes()
    rows = load_rows(codes)
    OUT_PATH.write_text(render(rows), encoding="utf-8")
    print(f"Wrote {len(rows)} cooking rows to {OUT_PATH}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
