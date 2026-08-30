#!/usr/bin/env python3
"""Extract the five frozen SukaSeafood I1 classes out of the Fish-Vista CSVs
into the dataset manifest schema required by 08 - CV Integration Contract.

Fish-Vista is a *seed*, not a dataset. Every row it produces is a museum
specimen photograph (iDigBio / preserved-specimen imagery), which is a
different visual domain from a Malaysian wet-market stall. Rows are emitted
with domain='SPECIMEN' so the split logic can keep them out of the retail
test set.

Usage:
    python build_manifest_from_fishvista.py --fishvista-dir data/ --out manifest_seed.csv
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import pathlib
import sys

# --- Frozen I1 class map (08 s.3). Do not edit without a scope change. -------
CLASS_MAP: dict[str, dict[str, str]] = {
    "rastrelliger kanagurta": {"class_code": "SF001", "label": "Kembung / Pelaling"},
    "parastromateus niger": {"class_code": "SF002", "label": "Bawal Hitam"},
    "lutjanus sebae": {"class_code": "SF003", "label": "Ikan Merah"},
    "oreochromis niloticus": {"class_code": "SF004", "label": "Tilapia"},
    "epinephelus coioides": {"class_code": "SF005", "label": "Kerapu Bintik"},
}

# Licences that are usable for a non-commercial university project. Anything
# not in this set is emitted with usable=REVIEW so a human decides.
CLEARLY_USABLE = {"CC BY", "CC BY-SA", "CC0", "Public Domain", "CC BY-NC", "CC BY-NC-SA 3.0"}

MANIFEST_FIELDS = [
    "image_id",          # stable id, used for dedup
    "class_code",
    "class_label",
    "scientific_name",
    "domain",            # SPECIMEN | RETAIL | WEB_WHOLE | INVALID
    "split",             # train | val | test_clean | test_dirty | test_invalid | UNASSIGNED
    "original_group_id", # all derivatives of one original share this
    "source",
    "source_url",
    "licence",
    "licence_usable",    # YES | REVIEW
    "attribution",
    "local_path",        # filled in after download
    "sha256",            # filled in after download
    "notes",
]


def group_id(row: dict) -> str:
    """One id per original photograph, so crops/augmentations never straddle splits."""
    basis = (row.get("original_url") or row.get("filename") or "").strip().lower()
    return hashlib.sha1(basis.encode()).hexdigest()[:16]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fishvista-dir", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    args = ap.parse_args()

    rows: list[dict] = []
    seen_groups: set[str] = set()

    for split_file in ("train", "val", "test"):
        path = args.fishvista_dir / f"FishVista-classification_{split_file}.csv"
        if not path.exists():
            print(f"  ! missing {path}, skipping", file=sys.stderr)
            continue
        with path.open(newline="", encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                species = (row.get("standardized_species") or "").strip().lower()
                if species not in CLASS_MAP:
                    continue
                gid = group_id(row)
                if gid in seen_groups:
                    continue  # cross-split duplicate in the source
                seen_groups.add(gid)
                cls = CLASS_MAP[species]
                licence = (row.get("license") or "").strip()
                rows.append({
                    "image_id": row.get("filename", ""),
                    "class_code": cls["class_code"],
                    "class_label": cls["label"],
                    "scientific_name": species,
                    "domain": "SPECIMEN",
                    "split": "UNASSIGNED",
                    "original_group_id": gid,
                    "source": f"Fish-Vista/{row.get('source', '')}",
                    "source_url": row.get("original_url", ""),
                    "licence": licence,
                    "licence_usable": "YES" if licence in CLEARLY_USABLE else "REVIEW",
                    "attribution": row.get("owner", ""),
                    "local_path": "",
                    "sha256": "",
                    "notes": f"fishvista_split={split_file}; museum specimen imagery",
                })

    rows.sort(key=lambda r: (r["class_code"], r["image_id"]))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=MANIFEST_FIELDS)
        w.writeheader()
        w.writerows(rows)

    print(f"wrote {len(rows)} rows -> {args.out}\n")
    print(f"{'class':<8} {'label':<22} {'rows':>5}  {'needs licence review':>20}")
    print("-" * 60)
    for code in sorted({r["class_code"] for r in rows}):
        sub = [r for r in rows if r["class_code"] == code]
        review = sum(1 for r in sub if r["licence_usable"] == "REVIEW")
        print(f"{code:<8} {sub[0]['class_label']:<22} {len(sub):>5}  {review:>20}")
    print("-" * 60)
    print(f"{'TOTAL':<31} {len(rows):>5}")
    print("\nThis is a seed, not a trainable dataset. Every row is specimen imagery;")
    print("retail images must be collected separately and marked domain=RETAIL.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
