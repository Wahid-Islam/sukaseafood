#!/usr/bin/env python3
"""Convert a Roboflow export into the class-folder layout train.sh expects.

Roboflow datasets are usually annotated for object detection: each image has
bounding boxes, and one photo can hold several fish of different species. Our
model is a whole-image classifier — one image in, one fish out.

So do not feed whole market photos to it. **Crop the boxes.** Each box becomes
one single-fish image with an unambiguous label, which is exactly the input the
model was designed for, and a photo of six fish yields six training images
instead of one confusing multi-label one.

Formats handled, in order of preference:

    COCO JSON        _annotations.coco.json per split   <- recommended
    Pascal VOC       one .xml beside each image
    Multi-label CSV  _classes.csv per split (no boxes; whole images, and any
                     image with two species is skipped as ambiguous)

    python scripts/import_roboflow.py --export ~/Downloads/fish-market.v1 \\
        --out ~/Downloads/fish-prepared
    ./train.sh ~/Downloads/fish-prepared
"""

from __future__ import annotations

import argparse
import collections
import csv
import json
import pathlib
import sys
import xml.etree.ElementTree as ET

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sukacv.classes import CLASSES, resolve_class  # noqa: E402

LABELS = {c.class_code: c.label for c in CLASSES}
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}

# Detection boxes are usually drawn tight. A classifier trained on tight crops
# sees no context and does poorly on ordinary photos, so pad outward a little.
MARGIN = 0.12
MIN_CROP_PX = 48


def detect_format(export: pathlib.Path) -> str:
    if list(export.rglob("_annotations.coco.json")):
        return "coco"
    if list(export.rglob("*.xml")):
        return "voc"
    if list(export.rglob("_classes.csv")):
        return "multilabel"
    return "unknown"


def crop_and_save(img_path: pathlib.Path, box, out_dir: pathlib.Path,
                  stem: str, index: int) -> bool:
    """box = (x0, y0, x1, y1) in pixels. Returns True when written."""
    try:
        with Image.open(img_path) as im:
            im = im.convert("RGB")
            W, H = im.size
            x0, y0, x1, y1 = box
            bw, bh = x1 - x0, y1 - y0
            if bw < 4 or bh < 4:
                return False
            x0 = max(0, x0 - bw * MARGIN)
            y0 = max(0, y0 - bh * MARGIN)
            x1 = min(W, x1 + bw * MARGIN)
            y1 = min(H, y1 + bh * MARGIN)
            if (x1 - x0) < MIN_CROP_PX or (y1 - y0) < MIN_CROP_PX:
                return False
            crop = im.crop((int(x0), int(y0), int(x1), int(y1)))
            out_dir.mkdir(parents=True, exist_ok=True)
            crop.save(out_dir / f"{stem}_{index:02d}.jpg", quality=92)
            return True
    except Exception as exc:  # noqa: BLE001
        print(f"  ! {img_path.name}: {exc}")
        return False


def import_coco(export: pathlib.Path, out: pathlib.Path, stats, unmapped):
    for ann_file in sorted(export.rglob("_annotations.coco.json")):
        split_dir = ann_file.parent
        data = json.loads(ann_file.read_text())
        categories = {c["id"]: c["name"] for c in data.get("categories", [])}
        images = {i["id"]: i for i in data.get("images", [])}

        by_image: dict[int, list] = collections.defaultdict(list)
        for a in data.get("annotations", []):
            by_image[a["image_id"]].append(a)

        for image_id, anns in by_image.items():
            info = images.get(image_id)
            if not info:
                continue
            img_path = split_dir / info["file_name"]
            if not img_path.exists():
                continue
            for i, a in enumerate(anns):
                raw = categories.get(a["category_id"], "")
                code = resolve_class(raw)
                if not code:
                    unmapped[raw] += 1
                    continue
                x, y, w, h = a["bbox"]
                if crop_and_save(img_path, (x, y, x + w, y + h), out / code,
                                 f"{split_dir.name}_{img_path.stem}", i):
                    stats[code] += 1


def import_voc(export: pathlib.Path, out: pathlib.Path, stats, unmapped):
    for xml_path in sorted(export.rglob("*.xml")):
        try:
            root = ET.parse(xml_path).getroot()
        except ET.ParseError:
            continue
        img_path = next(
            (xml_path.with_suffix(ext) for ext in IMAGE_EXTS
             if xml_path.with_suffix(ext).exists()), None)
        if img_path is None:
            continue
        for i, obj in enumerate(root.findall("object")):
            raw = (obj.findtext("name") or "").strip()
            code = resolve_class(raw)
            if not code:
                unmapped[raw] += 1
                continue
            bb = obj.find("bndbox")
            if bb is None:
                continue
            box = tuple(float(bb.findtext(k, "0")) for k in
                        ("xmin", "ymin", "xmax", "ymax"))
            if crop_and_save(img_path, box, out / code,
                             f"{xml_path.parent.name}_{img_path.stem}", i):
                stats[code] += 1


def import_multilabel(export: pathlib.Path, out: pathlib.Path, stats, unmapped):
    """No boxes available: whole images only, single-species photos only."""
    skipped_multi = 0
    for csv_path in sorted(export.rglob("_classes.csv")):
        split_dir = csv_path.parent
        with csv_path.open(newline="", encoding="utf-8-sig") as fh:
            rows = list(csv.DictReader(fh))
        for row in rows:
            fields = {k.strip(): v for k, v in row.items() if k}
            filename = fields.pop("filename", None) or fields.pop("file", None)
            if not filename:
                continue
            present = [name for name, val in fields.items()
                       if str(val).strip() in {"1", "1.0", "true", "True"}]
            codes = {resolve_class(n) for n in present}
            for n in present:
                if resolve_class(n) is None:
                    unmapped[n] += 1
            codes.discard(None)
            # A photo labelled with two species cannot train a single-label
            # classifier. Dropping it is correct; guessing one would be worse.
            if len(codes) != 1:
                if len(codes) > 1:
                    skipped_multi += 1
                continue
            code = codes.pop()
            src = split_dir / filename
            if not src.exists():
                continue
            dest_dir = out / code
            dest_dir.mkdir(parents=True, exist_ok=True)
            try:
                with Image.open(src) as im:
                    im.convert("RGB").save(
                        dest_dir / f"{split_dir.name}_{src.stem}.jpg", quality=92)
                stats[code] += 1
            except Exception as exc:  # noqa: BLE001
                print(f"  ! {src.name}: {exc}")
    if skipped_multi:
        print(f"\n  {skipped_multi} image(s) carried more than one species and "
              f"were skipped.")
        print("  A single-label classifier cannot learn from those. Re-export as "
              "COCO JSON")
        print("  to crop each fish out separately and keep them.")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--export", required=True, type=pathlib.Path,
                    help="the unzipped Roboflow export folder")
    ap.add_argument("--out", required=True, type=pathlib.Path,
                    help="where to write the class-folder dataset")
    ap.add_argument("--format", choices=["auto", "coco", "voc", "multilabel"],
                    default="auto")
    args = ap.parse_args()

    export = args.export.expanduser().resolve()
    out = args.out.expanduser().resolve()
    if not export.is_dir():
        print(f"error: {export} is not a directory")
        return 1

    fmt = args.format if args.format != "auto" else detect_format(export)
    if fmt == "unknown":
        print(f"Could not identify the export format in {export}.")
        print("Expected one of: _annotations.coco.json, *.xml, _classes.csv")
        return 1

    print(f"\nImporting {export}")
    print(f"Format: {fmt}" + ("  (crops each box into a single-fish image)"
                              if fmt in {"coco", "voc"} else
                              "  (whole images; no boxes to crop)"))
    print("=" * 68)

    stats: dict[str, int] = collections.Counter()
    unmapped: dict[str, int] = collections.Counter()

    {"coco": import_coco, "voc": import_voc,
     "multilabel": import_multilabel}[fmt](export, out, stats, unmapped)

    print(f"\n{'class':<8}{'label':<24}{'images':>8}")
    print("-" * 42)
    for c in CLASSES:
        n = stats.get(c.class_code, 0)
        flag = "" if n else "   <-- none found"
        print(f"{c.class_code:<8}{c.label:<24}{n:>8}{flag}")
    print("-" * 42)
    print(f"{'TOTAL':<32}{sum(stats.values()):>8}")

    if unmapped:
        print(f"\nLabels in the dataset that are not one of our five:")
        for name, n in unmapped.most_common(20):
            print(f"  {name!r:<40} {n:>6} annotations  (ignored)")
        print("\nIf one of those IS one of our five under a different name, add it")
        print("to ALIASES in sukacv/classes.py and re-run.")

    missing = [c.class_code for c in CLASSES if not stats.get(c.class_code)]
    print("\n" + "=" * 68)
    if missing:
        print(f"This dataset does not cover: "
              f"{', '.join(f'{m} {LABELS[m]}' for m in missing)}")
        print("A five-class model needs all five. Use this dataset for the "
              "classes it does")
        print("have and collect the rest, or find another dataset to combine "
              "with it.")
        return 1

    print(f"Written to {out}")
    print(f"Next:  ./train.sh {out} --inspect")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
