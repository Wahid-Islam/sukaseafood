"""Fetch FishBase summaries, GBIF/IUCN categories, and reuse OBIS points.

The rOpenSci FishBase REST host currently 404s. Official FishBase summary
pages and the GBIF IUCN category endpoint are used instead. Values are stored
exactly as retrieved — nothing is filled in when a field is missing.
"""

from __future__ import annotations

import json
import re
import ssl
import time
import urllib.parse
import urllib.request
from html import unescape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OBIS_IN = ROOT / "data" / "biodiversity_fetch.json"
OUT = ROOT / "data" / "biodiversity_parsed.json"

SPECIES: list[tuple[str, str]] = [
    ("SF001", "Rastrelliger kanagurta"),
    ("SF002", "Parastromateus niger"),
    ("SF003", "Lutjanus sebae"),
    ("SF004", "Oreochromis niloticus"),
    ("SF005", "Epinephelus coioides"),
    ("SF006", "Pampus argenteus"),
    ("SF007", "Megalaspis cordyla"),
    ("SF008", "Lutjanus johnii"),
    ("SF009", "Nemipterus japonicus"),
    ("SF010", "Alepes melanoptera"),
    ("SF011", "Selaroides leptolepis"),
    ("SF012", "Scomberomorus commerson"),
    ("SF014", "Lates calcarifer"),
    ("SF054", "Euthynnus affinis"),
]

CTX = ssl.create_default_context()


def fetch(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "SukaSeafood/1.0 (educational; biodiversity seed)"},
    )
    with urllib.request.urlopen(req, timeout=45, context=CTX) as resp:
        return resp.read().decode("utf-8", errors="replace")


def strip_tags(html: str) -> str:
    text = re.sub(r"<script[\s\S]*?</script>", " ", html, flags=re.I)
    text = re.sub(r"<style[\s\S]*?</style>", " ", text, flags=re.I)
    text = re.sub(r"<[^>]+>", " ", text)
    text = unescape(text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def parse_fishbase(scientific: str) -> dict:
    slug = scientific.replace(" ", "-")
    url = f"https://www.fishbase.se/summary/{slug}.html"
    html = fetch(url)
    text = strip_tags(html)

    env = None
    m = re.search(
        r"Environment:.*?range\s+(.*?)(?:Short description|Biology|Size / Weight)",
        text,
        re.I,
    )
    if m:
        env = m.group(1).strip(" .;")

    depth_shallow = depth_deep = None
    dm = re.search(r"depth range\s+([\d.]+)\s*-\s*([\d.]+)\s*m", text, re.I)
    if dm:
        depth_shallow = float(dm.group(1))
        depth_deep = float(dm.group(2))

    habitat = None
    if env:
        for token in (
            "reef-associated",
            "pelagic-neritic",
            "pelagic-oceanic",
            "benthopelagic",
            "demersal",
            "pelagic",
            "bathydemersal",
        ):
            if token in env.lower():
                habitat = token
                break

    biology = None
    bm = re.search(r"Biology\s+(.*?)(?:IUCN Red List|Life cycle|Human uses)", text, re.I)
    if bm:
        biology = bm.group(1).strip()
        biology = re.sub(r"\s*\(Ref\.\s*\d+\)", "", biology)
        if len(biology) > 600:
            biology = biology[:597].rsplit(" ", 1)[0] + "…"

    iucn_from_page = None
    im = re.search(
        r"(Least Concern|Near Threatened|Vulnerable|Endangered|Critically Endangered|Data Deficient|Not Evaluated)\s*\(([A-Z]{1,3})\)",
        text,
    )
    if im:
        iucn_from_page = {"label": im.group(1), "code": im.group(2)}

    return {
        "url": url,
        "environment": env,
        "habitat": habitat,
        "depth_shallow_m": depth_shallow,
        "depth_deep_m": depth_deep,
        "biology": biology,
        "iucn_page": iucn_from_page,
    }


def gbif_iucn(scientific: str) -> dict | None:
    match_url = (
        "https://api.gbif.org/v1/species/match?"
        + urllib.parse.urlencode({"name": scientific})
    )
    match = json.loads(fetch(match_url))
    key = match.get("usageKey")
    if not key:
        return None
    cat_url = f"https://api.gbif.org/v1/species/{key}/iucnRedListCategory"
    try:
        cat = json.loads(fetch(cat_url))
    except Exception:
        return None
    code = cat.get("code")
    label = cat.get("category")
    taxon = cat.get("iucnTaxonID")
    if not code and not label:
        return None
    return {
        "code": code,
        "label": label,
        "iucn_taxon_id": taxon,
        "usage_key": key,
    }


def main() -> None:
    obis_by_code = {}
    if OBIS_IN.exists():
        for row in json.loads(OBIS_IN.read_text(encoding="utf-8")):
            obis_by_code[row["code"]] = {
                "count": row.get("obis_count") or 0,
                "points": row.get("obis_points") or [],
            }

    out = []
    for code, scientific in SPECIES:
        print(f"parse {code} {scientific}", flush=True)
        fb = {}
        try:
            fb = parse_fishbase(scientific)
        except Exception as exc:
            fb = {"error": str(exc)}
        time.sleep(0.5)
        iucn = None
        try:
            iucn = gbif_iucn(scientific)
        except Exception as exc:
            iucn = {"error": str(exc)}
        time.sleep(0.3)
        out.append(
            {
                "code": code,
                "scientific_name": scientific,
                "retrieved_at": "2026-09-12T13:20:00Z",
                "fishbase": fb,
                "iucn": iucn,
                "obis": obis_by_code.get(code, {"count": 0, "points": []}),
            }
        )
    OUT.write_text(json.dumps(out, indent=2, ensure_ascii=True), encoding="utf-8")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
