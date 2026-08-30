#!/usr/bin/env python3
"""Add a folder of collected photographs to the manifest.

This is the path that actually produces a usable I1 model: team members go to
wet markets and supermarkets, photograph the five fish, and drop the files into

    incoming/SF001/...  incoming/SF002/...  etc.

Every ingested row gets domain=RETAIL and provenance the team must fill in.
Rows whose licence/permission is unclear are marked REVIEW, not YES.

    python scripts/ingest_folder.py --incoming incoming --out-dir data/images \
        --manifest data/manifest.csv --domain RETAIL --split test_dirty \
        --source "Pasar Borong Selayang, 2026-08-30" --attribution "A. Sharma"
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import pathlib

from PIL import Image

import sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from sukacv.classes import CLASSES, resolve_class  # noqa: E402

CODE_TO_CLASS = {c.class_code: c for c in CLASSES}
EXTS = {".jpg", ".jpeg", ".png", ".webp"}
MANIFEST_FIELDS = [
    "image_id", "class_code", "class_label", "scientific_name", "domain", "split",
    "original_group_id", "source", "source_url", "licence", "licence_usable",
    "attribution", "local_path", "sha256", "notes",
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--incoming", required=True, type=pathlib.Path,
                    help="folder with one subfolder per fish. Names may be class "
                         "codes (SF001..SF005) or common names (kembung, tilapia, "
                         "grouper...); see scripts/inspect_dataset.py")
    ap.add_argument("--out-dir", required=True, type=pathlib.Path)
    ap.add_argument("--manifest", required=True, type=pathlib.Path,
                    help="manifest to append to; created if absent")
    ap.add_argument("--domain", default="RETAIL",
                    choices=["RETAIL", "SPECIMEN", "WEB_WHOLE", "INVALID"])
    ap.add_argument("--split", default="UNASSIGNED",
                    choices=["UNASSIGNED", "test_dirty", "test_invalid"],
                    help="test_dirty pins these out of training permanently")
    ap.add_argument("--source", required=True, help="where and when, e.g. 'Pasar Chow Kit 2026-08-30'")
    ap.add_argument("--attribution", required=True, help="who took the photo")
    ap.add_argument("--licence", default="own-work, team permission granted")
    args = ap.parse_args()

    existing: list[dict] = []
    if args.manifest.exists():
        with args.manifest.open(newline="", encoding="utf-8") as fh:
            existing = list(csv.DictReader(fh))
    known = {r["sha256"] for r in existing if r.get("sha256")}

    added, dupes, bad = 0, 0, 0
    new_rows: list[dict] = []

    # Accept whatever the dataset author named their folders. Anything that
    # does not resolve is reported, never guessed at.
    folders: dict[str, list[pathlib.Path]] = {}
    unmapped: list[pathlib.Path] = []
    for child in sorted(args.incoming.iterdir()):
        if not child.is_dir() or child.name.startswith("."):
            continue
        code = resolve_class(child.name)
        if code:
            folders.setdefault(code, []).append(child)
        else:
            unmapped.append(child)

    if unmapped:
        print(f"  ! {len(unmapped)} folder(s) not recognised and SKIPPED:")
        for d in unmapped:
            print(f"      {d.name}")
        print("    Rename them to a class code or a recognised name to include them.")

    for code, cls in CODE_TO_CLASS.items():
        dirs = folders.get(code, [])
        if not dirs:
            print(f"  (no folder for {code} {cls.label})")
            continue
        for folder in dirs:
            for path in sorted(p for p in folder.rglob("*")
                               if p.suffix.lower() in EXTS and p.is_file()):
                data = path.read_bytes()
                digest = hashlib.sha256(data).hexdigest()
                if digest in known:
                    dupes += 1
                    continue
                try:
                    with Image.open(path) as im:
                        im.verify()
                except Exception:  # noqa: BLE001
                    print(f"  ! unreadable, skipped: {path.name}")
                    bad += 1
                    continue

                rel = f"{code}/{digest[:16]}{path.suffix.lower()}"
                dest = args.out_dir / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(data)
                known.add(digest)

                new_rows.append({
                    "image_id": rel,
                    "class_code": code,
                    "class_label": cls.label,
                    "scientific_name": cls.scientific_name,
                    "domain": args.domain,
                    "split": args.split,
                    # One group per original file. Crops of this photo added
                    # later must reuse this id so they cannot straddle splits.
                    "original_group_id": digest[:16],
                    "source": args.source,
                    "source_url": "",
                    "licence": args.licence,
                    "licence_usable": "YES" if "own-work" in args.licence else "REVIEW",
                    "attribution": args.attribution,
                    "local_path": rel,
                    "sha256": digest,
                    "notes": f"ingested from {folder.name}/{path.name}",
                })
                added += 1

    all_rows = existing + new_rows
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    with args.manifest.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=MANIFEST_FIELDS)
        w.writeheader()
        w.writerows(all_rows)

    print(f"\nadded {added}, skipped {dupes} duplicates, {bad} unreadable")
    print(f"manifest now has {len(all_rows)} rows -> {args.manifest}")
    print("\nper class after ingest:")
    for code in CODE_TO_CLASS:
        n = sum(1 for r in all_rows if r["class_code"] == code)
        retail = sum(1 for r in all_rows
                     if r["class_code"] == code and r.get("domain") == "RETAIL")
        flag = "" if retail >= 150 else "   <-- under target"
        print(f"  {code}  total {n:>4}   retail {retail:>4}{flag}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
