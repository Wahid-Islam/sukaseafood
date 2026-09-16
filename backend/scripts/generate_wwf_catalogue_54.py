#!/usr/bin/env python3
"""Build the 54-fish WWF catalogue seed from the labeled CSV.

    cd backend && python scripts/generate_wwf_catalogue_54.py

Existing codes SF001–SF012, SF014 and SF015 are kept. SF013 Demuduk is
kept inactive for PriceCatcher/forecast keys and is not a WWF listing.
New WWF species start at SF016.
Tongkol (SF015) is WWF's *Thunnus tonggol*; Kawakawa / Tongkol Kurik gets
a new code so the earlier Euthynnus biodiversity extract can move with it.
"""

from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CSV_PATH = ROOT / "data" / "wwf_fish_context_55_words_max_with_short_descriptions.csv"
IDS_PATH = ROOT / "data" / "wwf_catalogue_54_ids.json"
ITEMS_PATH = ROOT / "backend" / "db" / "seed" / "10_wwf_catalogue_54.sql"
WWF_PATH = ROOT / "backend" / "db" / "seed" / "11_wwf_sos_2022.sql"
REPOINT_PATH = ROOT / "backend" / "db" / "seed" / "16_repoint_tongkol_biodiversity.sql"

SNAPSHOT = "wwf-sos-2022-54-context"
CV_CODES = {"SF001", "SF002", "SF007", "SF008", "SF012"}

EXISTING = {
    "Kembung / Pelaling": "SF001",
    "Bawal Hitam": "SF002",
    "Ikan Merah": "SF003",
    "Tilapia": "SF004",
    "Kerapu Bintik": "SF005",
    "Bawal Putih": "SF006",
    "Cencaru": "SF007",
    "Jenahak": "SF008",
    "Kerisi": "SF009",
    "Pelata": "SF010",
    "Selar Kuning": "SF011",
    "Tenggiri": "SF012",
    "Siakap Putih": "SF014",
    "Tongkol": "SF015",
}

FAMILIES = {
    "gadus chalcogrammus": "Gadidae",
    "thunnus alalunga": "Scombridae",
    "thunnus thynnus": "Scombridae",
    "gadus morhua": "Gadidae",
    "salmo salar": "Salmonidae",
    "katsuwonus pelamis": "Scombridae",
    "trachinotus blochii": "Carangidae",
    "parastromateus niger": "Carangidae",
    "pampus chinensis": "Stromateidae",
    "valamugil cunnesius": "Mugilidae",
    "coilia spp.": "Engraulidae",
    "sillago sihama": "Sillaginidae",
    "megalaspis cordyla": "Carangidae",
    "oncorhynchus tshawytscha": "Salmonidae",
    "macruronus novaezelandiae": "Merlucciidae",
    "stolephorus spp.": "Engraulidae",
    "caesio cuning": "Caesionidae",
    "sciaenidae spp.": "Sciaenidae",
    "lutjanus sebae": "Lutjanidae",
    "pseudorhombus malayanus": "Paralichthyidae",
    "decapterus akaadsi": "Carangidae",
    "lutjanus johnii": "Lutjanidae",
    "elasmobranchii": "Elasmobranchii",
    "sphyraena jello": "Sphyraenidae",
    "rastrelliger kanagurta": "Scombridae",
    "epinephelus sexfasciatus": "Serranidae",
    "epinephelus coioides": "Serranidae",
    "epinephelus bleekeri": "Serranidae",
    "epinephelus fuscoguttatus": "Serranidae",
    "epinephelus lanceolatus": "Serranidae",
    "epinephelus malabaricus": "Serranidae",
    "plectropomus spp.": "Serranidae",
    "cromileptes altivelis": "Serranidae",
    "cromileptis altivelis": "Serranidae",
    "caranx sexfasciatus": "Carangidae",
    "nemipterus japiconus": "Nemipteridae",
    "nemipterus japonicus": "Nemipteridae",
    "leiognathus spp.": "Leiognathidae",
    "lutjanus vitta": "Lutjanidae",
    "polydactylus plebeius": "Polynemidae",
    "cheilinus undulatus": "Labridae",
    "selar crumenophthalmus": "Carangidae",
    "chirocentrus dorab": "Chirocentridae",
    "chondrichthyes": "Chondrichthyes",
    "pangasius bocourti": "Pangasiidae",
    "alepes melanoptera": "Carangidae",
    "selaroides leptolepis": "Carangidae",
    "lutjanus argentimaculatus": "Lutjanidae",
    "lates calcarifer": "Latidae",
    "spratelloides gracilis": "Clupeidae",
    "scomberomorus commerson": "Scombridae",
    "tenualosa macrura": "Dorosomatidae",
    "oreochromis niloticus": "Cichlidae",
    "thunnus tonggol": "Scombridae",
    "euthynnus affinis": "Scombridae",
    "auxis thazard": "Scombridae",
}

RATING_MAP = {
    "best choice": "BEST_CHOICE",
    "reduce": "REDUCE",
    "avoid": "AVOID",
}

TYPOS = {
    "nemipterus japiconus": "nemipterus japonicus",
    "cromileptis altivelis": "cromileptes altivelis",
}

ORIGIN_CODES = {
    "usa": "US",
    "south africa": "ZA",
    "russia (barrent sea)": "RU",
    "norway": "NO",
    "alaska": "US",
    "new zealand": "NZ",
    "vietnam": "VN",
}


def sql_str(value: str | None) -> str:
    if value is None or not str(value).strip() or str(value).strip() == "-":
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def norm_sci(value: str) -> str:
    cleaned = re.sub(r"\s+", " ", value.strip().lower())
    return TYPOS.get(cleaned, cleaned)


def load_rows() -> list[dict[str, str]]:
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        raw_rows = list(csv.DictReader(handle))
    cleaned: list[dict[str, str]] = []
    for row in raw_rows:
        cleaned.append(
            {
                (key or "").lstrip("\ufeff").strip(): (
                    value if value is not None else ""
                )
                for key, value in row.items()
                if key is not None
            }
        )
    return cleaned


def assign_codes(rows: list[dict[str, str]]) -> dict[str, str]:
    mapping: dict[str, str] = dict(EXISTING)
    next_n = 16
    for row in rows:
        name = row["main_common_name"].strip()
        if name in mapping:
            continue
        mapping[name] = f"SF{next_n:03d}"
        next_n += 1
    return mapping


def taxonomic_level(scientific: str) -> str:
    lowered = scientific.lower()
    if lowered in {"elasmobranchii", "chondrichthyes"}:
        return "class"
    if "spp" in lowered or lowered.endswith("idae"):
        return "family" if lowered.endswith("idae spp.") or lowered.endswith("idae") else "genus"
    return "species"


def fish_type(raw: str) -> str:
    text = re.sub(r"\s+", " ", raw.strip())
    text = re.sub(r" fish$", "", text, flags=re.I)
    return text.lower() or "seafood"


def production_type(method: str) -> str:
    lowered = method.lower()
    if any(word in lowered for word in ("farmed", "cage", "pond", "aquaculture")):
        return "FARMED"
    return "WILD"


def method_code(method: str) -> str:
    lowered = method.lower()
    if "cyanide" in lowered:
        return "OTHER"
    if "purse" in lowered:
        return "PURSE_SEINE"
    if "trawl" in lowered:
        return "TRAWL"
    if "gill" in lowered:
        return "GILLNET"
    if "hook" in lowered or "line" in lowered or "pole" in lowered:
        return "HOOK_AND_LINE"
    if "cage" in lowered or "pond" in lowered or "farmed" in lowered:
        return "AQUACULTURE"
    if "lift" in lowered or "seine" in lowered:
        return "OTHER"
    return "OTHER"


def origin_code(origin: str) -> str | None:
    lowered = origin.strip().lower()
    if "malaysia" in lowered:
        return "MY"
    return ORIGIN_CODES.get(lowered)


def origin_clean(origin: str) -> str:
    text = origin.strip()
    if text.endswith("&") or text.endswith("&,"):
        return "Malaysia (East Coast)"
    return text


def image_url(code: str) -> str:
    return f"https://sukaseafood-654b7.web.app/catalogue/{code}.jpg"


def aliases_for(row: dict[str, str], code: str) -> list[tuple[str, str, str]]:
    name = row["main_common_name"].strip()
    secondary = (row.get("secondary_common_name") or "").strip()
    scientific = row["scientific_name"].strip()
    rows: list[tuple[str, str, str]] = [(name, "ms", "MALAY")]
    if " / " in name:
        for part in name.split(" / "):
            part = part.strip()
            if part and part != name:
                rows.append((part, "ms", "MALAY"))
    if not name.lower().startswith("ikan "):
        rows.append((f"Ikan {name.split(' / ')[0]}", "ms", "MALAY"))
    if secondary and secondary != "-":
        for part in re.split(r"\s*/\s*", secondary):
            rows.append((part.strip(), "en", "ENGLISH_COMMON"))
    rows.append((scientific, "la", "SCIENTIFIC"))
    if code == "SF015":
        rows.append(("Longtail Tuna", "en", "ENGLISH_COMMON"))
    seen: set[str] = set()
    unique: list[tuple[str, str, str]] = []
    for alias, lang, kind in rows:
        key = alias.strip().lower()
        if not alias or key in seen:
            continue
        seen.add(key)
        unique.append((alias.strip(), lang, kind))
    return unique


def render_items(groups: dict[str, list[dict[str, str]]], codes: dict[str, str]) -> str:
    item_sql: list[str] = []
    alias_sql: list[str] = []
    for name, group in groups.items():
        row = group[0]
        code = codes[name]
        scientific = row["scientific_name"].strip()
        if name == "Kerapu Tikus":
            scientific = "Cromileptes altivelis"
        if name == "Kerisi":
            scientific = "Nemipterus japonicus"
        sci_norm = norm_sci(scientific)
        family = FAMILIES.get(sci_norm) or FAMILIES.get(scientific.lower())
        if family is None:
            raise SystemExit(f"missing family for {scientific}")
        description = (row.get("description") or "").strip()
        secondary = (row.get("secondary_common_name") or "").strip()
        display = secondary if secondary and secondary != "-" else name
        item_sql.append(
            "  ("
            + ", ".join(
                [
                    sql_str(code),
                    sql_str(name),
                    sql_str(display),
                    sql_str(scientific),
                    sql_str(taxonomic_level(scientific)),
                    sql_str(family),
                    sql_str(fish_type(row.get("fish_type") or "")),
                    sql_str(description),
                    "TRUE" if code in CV_CODES else "FALSE",
                    sql_str(image_url(code)),
                    sql_str(
                        "WWF Save Our Seafood listing. Ratings stay "
                        "on retrieved catch-method rows only."
                    ),
                ]
            )
            + ")"
        )
        for alias, lang, kind in aliases_for(row, code):
            alias_sql.append(
                "  ("
                + ", ".join(
                    [sql_str(code), sql_str(alias), sql_str(lang), sql_str(kind)]
                )
                + ")"
            )
    return f"""-- =========================================================
-- 10_wwf_catalogue_54.sql   ** GENERATED FILE — DO NOT EDIT **
-- =========================================================
-- Regenerate with:  cd backend && python scripts/generate_wwf_catalogue_54.py
-- Source: data/wwf_fish_context_55_words_max_with_short_descriptions.csv
-- 54 WWF-listed fishes. SF013 Demuduk is inactive and is not listed here.

BEGIN;

INSERT INTO seafood_item (
  seafood_item_id, code, canonical_name_ms, display_name_en,
  scientific_name, scientific_name_normalized, taxonomic_level, family,
  fish_type, description, supports_cv, active, notes, primary_image_url
)
SELECT
  suka_uuid5('seafood_item:' || v.code),
  v.code, v.canonical_name_ms, v.display_name_en,
  v.scientific_name, lower(trim(v.scientific_name)), v.taxonomic_level, v.family,
  v.fish_type, v.description, v.supports_cv, TRUE, v.notes, v.primary_image_url
FROM (VALUES
{',\n'.join(item_sql)}
) AS v(code, canonical_name_ms, display_name_en, scientific_name,
       taxonomic_level, family, fish_type, description, supports_cv,
       primary_image_url, notes)
ON CONFLICT (seafood_item_id) DO UPDATE SET
  code                       = EXCLUDED.code,
  canonical_name_ms          = EXCLUDED.canonical_name_ms,
  display_name_en            = EXCLUDED.display_name_en,
  scientific_name            = EXCLUDED.scientific_name,
  scientific_name_normalized = EXCLUDED.scientific_name_normalized,
  taxonomic_level            = EXCLUDED.taxonomic_level,
  family                     = EXCLUDED.family,
  fish_type                  = EXCLUDED.fish_type,
  description                = EXCLUDED.description,
  supports_cv                = EXCLUDED.supports_cv,
  active                     = EXCLUDED.active,
  notes                      = EXCLUDED.notes,
  primary_image_url          = EXCLUDED.primary_image_url,
  updated_at                 = now();

INSERT INTO seafood_alias (
  seafood_alias_id, seafood_item_id, alias_name, language_code, alias_type, verified
)
SELECT
  suka_uuid5('seafood_alias:' || v.code || ':' || lower(trim(v.alias_name))),
  suka_uuid5('seafood_item:' || v.code),
  v.alias_name, v.language_code, v.alias_type::seafood_alias_type_enum, TRUE
FROM (VALUES
{',\n'.join(alias_sql)}
) AS v(code, alias_name, language_code, alias_type)
WHERE NOT EXISTS (
  SELECT 1
  FROM seafood_alias existing
  WHERE existing.seafood_item_id = suka_uuid5('seafood_item:' || v.code)
    AND lower(trim(existing.alias_name)) = lower(trim(v.alias_name))
);

COMMIT;
"""


def render_wwf(rows: list[dict[str, str]], codes: dict[str, str]) -> str:
    value_sql: list[str] = []
    for row in rows:
        name = row["main_common_name"].strip()
        code = codes[name]
        rating = RATING_MAP[row["sustainability_rating"].strip().lower()]
        method = row.get("production_method_final") or ""
        origin = origin_clean(row.get("origin") or "")
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
                    sql_str(origin_code(origin)),
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
-- Regenerate with:  cd backend && python scripts/generate_wwf_catalogue_54.py
-- Source: data/wwf_fish_context_55_words_max_with_short_descriptions.csv

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
  '2026-09-14T00:00:00+08:00'::timestamptz,
  'MANUAL_PDF_TRANSCRIPTION'::collection_method_enum,
  '{{"files": ["wwf_fish_context_55_words_max_with_short_descriptions.csv"]}}'::jsonb,
  'WWF Save Our Seafood listings with retrieved 55-word context copy.'
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


def render_repoint(kurik_code: str) -> str:
    return f"""-- Move the retrieved Euthynnus affinis biodiversity extract off SF015.
-- WWF now lists SF015 Tongkol as Thunnus tonggol; Kawakawa is {kurik_code}.
-- Idempotent: 15_biodiversity.sql may re-attach the extract to SF015.

BEGIN;

UPDATE biodiversity_occurrence
SET seafood_item_id = suka_uuid5('seafood_item:{kurik_code}')
WHERE seafood_item_id = suka_uuid5('seafood_item:SF015');

DELETE FROM biodiversity_profile
WHERE seafood_item_id = suka_uuid5('seafood_item:SF015')
  AND EXISTS (
    SELECT 1
    FROM biodiversity_profile existing
    WHERE existing.seafood_item_id = suka_uuid5('seafood_item:{kurik_code}')
  );

UPDATE biodiversity_profile
SET seafood_item_id = suka_uuid5('seafood_item:{kurik_code}')
WHERE seafood_item_id = suka_uuid5('seafood_item:SF015');

DELETE FROM seafood_alias
WHERE seafood_item_id = suka_uuid5('seafood_item:SF015')
  AND lower(trim(alias_name)) IN ('kawakawa', 'euthynnus affinis');

COMMIT;
"""


def main() -> int:
    if not CSV_PATH.is_file():
        print(f"missing {CSV_PATH}", file=sys.stderr)
        return 1
    rows = load_rows()
    codes = assign_codes(rows)
    groups: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        groups.setdefault(row["main_common_name"].strip(), []).append(row)
    if len(groups) != 54:
        print(f"expected 54 unique fishes, got {len(groups)}", file=sys.stderr)
        return 1
    kurik = codes["Tongkol Kurik"]
    IDS_PATH.write_text(
        json.dumps(
            {
                "wwf_listed": 54,
                "demuduk_inactive": "SF013",
                "tongkol_thunnus_tonggol": "SF015",
                "tongkol_kurik_euthynnus_affinis": kurik,
                "codes": codes,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )
    ITEMS_PATH.write_text(render_items(groups, codes), encoding="utf-8")
    WWF_PATH.write_text(render_wwf(rows, codes), encoding="utf-8")
    REPOINT_PATH.write_text(render_repoint(kurik), encoding="utf-8")
    print(f"Wrote {len(groups)} fishes to {ITEMS_PATH}", file=sys.stderr)
    print(f"Wrote {len(rows)} WWF rows to {WWF_PATH}", file=sys.stderr)
    print(f"Tongkol Kurik is {kurik}", file=sys.stderr)
    for name, code in codes.items():
        print(f"  {code}  {name}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
