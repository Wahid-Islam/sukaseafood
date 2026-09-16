#!/usr/bin/env python3
"""Convert labeled WWF photos to JPEG and upload them to Firebase Storage.

    cd backend && python scripts/upload_wwf_catalogue_photos.py
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
IDS_PATH = ROOT / "data" / "wwf_catalogue_54_ids.json"
PHOTO_DIR = (
    ROOT
    / "frontend"
    / "Images"
    / "11. Fish Photos (Complete List)-20260914T115111Z-1-001"
    / "11. Fish Photos (Complete List)"
)
OUT_DIR = ROOT / "backend" / ".cache" / "catalogue-jpg"
BUCKET = "gs://sukaseafood-654b7.firebasestorage.app/seafood"
GSUTIL = Path(
    r"C:\Users\Wahid\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd"
)


def key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def match_photo(name: str, photos: dict[str, Path]) -> Path:
    want = key(name)
    if want in photos:
        return photos[want]
    for stem, path in photos.items():
        if want.startswith(stem) or stem.startswith(want):
            return path
    raise SystemExit(f"no photo for {name}")


def convert(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(src) as image:
        rgb = image.convert("RGB")
        rgb.thumbnail((1200, 1200))
        rgb.save(dest, format="JPEG", quality=85, optimize=True)


def main() -> int:
    codes = json.loads(IDS_PATH.read_text(encoding="utf-8"))["codes"]
    photos = {key(path.stem): path for path in PHOTO_DIR.glob("*.png")}
    if len(photos) != 54:
        print(f"expected 54 photos, found {len(photos)}", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for name, code in codes.items():
        src = match_photo(name, photos)
        dest = OUT_DIR / f"{code}.jpg"
        convert(src, dest)
        written.append(dest)
        print(f"{code}  {src.name} -> {dest.name}", file=sys.stderr)
    gsutil = str(GSUTIL if GSUTIL.is_file() else "gsutil")
    cmd = [
        gsutil,
        "-m",
        "-h",
        "Content-Type:image/jpeg",
        "-h",
        "Cache-Control:public,max-age=86400",
        "cp",
        *[str(path) for path in written],
        f"{BUCKET}/",
    ]
    print("Uploading to", BUCKET, file=sys.stderr)
    subprocess.check_call(cmd)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
