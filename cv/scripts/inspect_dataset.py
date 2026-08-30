#!/usr/bin/env python3
"""Report what is in a dataset folder before anything is ingested.

Datasets arrive in whatever shape their author chose. This reads a folder,
works out its layout, maps every class directory to one of the frozen five, and
prints what it found — without writing anything.

Layouts understood:

    dataset/SF001/*.jpg                     class directories at the top
    dataset/kembung/*.jpg                   named however people name them
    dataset/train/kembung/*.jpg             split directories on the outside
    dataset/kembung/train/*.jpg             split directories on the inside

Anything it cannot map is listed rather than guessed at. A folder quietly
dropped into the wrong class is the most expensive kind of dataset bug: it
trains the model to be confidently wrong.

    python scripts/inspect_dataset.py --dataset ~/Downloads/fish-dataset
"""

from __future__ import annotations

import argparse
import collections
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sukacv.classes import CLASSES, resolve_class  # noqa: E402

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff"}
SPLIT_NAMES = {
    "train": "train", "training": "train",
    "val": "val", "valid": "val", "validation": "val", "dev": "val",
    "test": "test", "testing": "test", "eval": "test",
}
LABELS = {c.class_code: c.label for c in CLASSES}


def count_images(folder: pathlib.Path) -> int:
    return sum(1 for p in folder.rglob("*") if p.suffix.lower() in IMAGE_EXTS)


def is_split(name: str) -> str | None:
    return SPLIT_NAMES.get(name.lower().strip())


def scan(root: pathlib.Path):
    """Return (entries, unmapped, layout) where entries are (code, split, dir, n)."""
    entries: list[tuple[str, str | None, pathlib.Path, int]] = []
    unmapped: list[pathlib.Path] = []
    layout = "class-at-top"

    top = sorted(d for d in root.iterdir() if d.is_dir() and not d.name.startswith("."))
    if not top:
        return entries, unmapped, "empty"

    if all(is_split(d.name) for d in top):
        layout = "split-at-top"
        for split_dir in top:
            split = is_split(split_dir.name)
            for class_dir in sorted(d for d in split_dir.iterdir() if d.is_dir()):
                code = resolve_class(class_dir.name)
                if code:
                    entries.append((code, split, class_dir, count_images(class_dir)))
                else:
                    unmapped.append(class_dir)
        return entries, unmapped, layout

    for class_dir in top:
        code = resolve_class(class_dir.name)
        if not code:
            unmapped.append(class_dir)
            continue
        inner = [d for d in class_dir.iterdir() if d.is_dir() and is_split(d.name)]
        if inner:
            layout = "split-inside-class"
            for split_dir in sorted(inner):
                entries.append((code, is_split(split_dir.name), split_dir,
                                count_images(split_dir)))
        else:
            entries.append((code, None, class_dir, count_images(class_dir)))
    return entries, unmapped, layout


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", required=True, type=pathlib.Path)
    args = ap.parse_args()

    root = args.dataset.expanduser().resolve()
    if not root.is_dir():
        print(f"error: {root} is not a directory")
        return 1

    print(f"\nInspecting {root}\n" + "=" * 68)
    entries, unmapped, layout = scan(root)

    if layout == "empty":
        print("\nNo subdirectories found. Expected one directory per fish, e.g.")
        print("  dataset/kembung/  dataset/bawal_hitam/  dataset/ikan_merah/ ...")
        return 1

    print(f"\nLayout detected: {layout}")

    print(f"\n{'class':<8}{'label':<22}{'folder':<28}{'split':>8}{'images':>8}")
    print("-" * 74)
    per_class: dict[str, int] = collections.Counter()
    for code, split, folder, n in sorted(entries, key=lambda e: (e[0], e[1] or "")):
        rel = str(folder.relative_to(root))
        if len(rel) > 26:
            rel = "..." + rel[-23:]
        print(f"{code:<8}{LABELS[code]:<22}{rel:<28}{split or '-':>8}{n:>8}")
        per_class[code] += n

    print("-" * 74)
    print(f"{'TOTAL':<58}{sum(per_class.values()):>16}")

    missing = [c.class_code for c in CLASSES if per_class.get(c.class_code, 0) == 0]
    if missing:
        print(f"\nMISSING ENTIRELY: {', '.join(f'{m} {LABELS[m]}' for m in missing)}")
        print("A five-class model cannot be trained without all five.")

    if unmapped:
        print(f"\n{len(unmapped)} folder(s) could not be matched to any of the five:")
        for d in unmapped[:15]:
            print(f"  {d.relative_to(root)}   ({count_images(d)} images)")
        if len(unmapped) > 15:
            print(f"  ... and {len(unmapped) - 15} more")
        print("\nIf one of these IS one of the five, rename it to the class code")
        print("(SF001..SF005) or a recognised name, then re-run. If it is a")
        print("different species, it belongs in the invalid/unsupported set —")
        print("useful for testing 'None of these', never for training.")

    counts = [per_class.get(c.class_code, 0) for c in CLASSES]
    if all(counts):
        ratio = max(counts) / min(counts)
        print(f"\nClass balance: {min(counts)}–{max(counts)} images "
              f"({ratio:.1f}x imbalance)")
        if ratio > 3:
            print("  Over 3x. Class weights are applied automatically, but the")
            print("  thin classes will still be the weak ones.")
        if min(counts) < 30:
            print("  Under 30 images in the smallest class: expect a model that")
            print("  learns something but is not trustworthy. 150+ is the floor")
            print("  for a model anyone should rely on.")

    print("\n" + "=" * 68)
    if missing or not entries:
        print("NOT READY — see above.")
        return 1
    print("Ready to ingest. Next:")
    print(f"  ./train.sh {args.dataset}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
