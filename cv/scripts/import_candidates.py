#!/usr/bin/env python3
"""Build the training manifest from the corpus's own candidates.csv.

sukaseafood-fish-images already ships a manifest with everything the training
pipeline needs — sha256, perceptual hash, licence, attribution, source URL and
a species code per image. Re-deriving any of that would throw away provenance
the collection process already established, so this reads it rather than
walking the directory tree.

What it does beyond a straight copy:

  1. Resolves seafood_code to a frozen class index, and says plainly when a
     species is in the catalogue but has no images (SF003/SF004/SF005) versus
     genuinely unknown.
  2. Deduplicates on sha256 (byte-identical) and then on perceptual hash
     (visually identical, different bytes — the same photo re-encoded by two
     aggregators, which is common across GBIF/iNaturalist/ALA).
  3. Assigns original_group_id, which the corpus leaves blank. Near-duplicates
     share a group so they cannot straddle a split; that is what keeps the
     accuracy figure honest.
  4. Marks licence usability. Everything here is CC/public-domain, but CC-BY-NC
     forbids commercial use, which is a decision for the team, not a script.

    python scripts/import_candidates.py \\
        --candidates ~/Downloads/sukaseafood-fish-images/candidates.csv \\
        --images-root ~/Downloads/sukaseafood-fish-images/images \\
        --out data/manifest.csv
"""

from __future__ import annotations

import argparse
import collections
import csv
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sukacv.classes import CLASSES, explain_unresolved, resolve_class  # noqa: E402

LABELS = {c.class_code: c.label for c in CLASSES}

MANIFEST_FIELDS = [
    "image_id", "class_code", "class_label", "scientific_name", "domain", "split",
    "original_group_id", "source", "source_url", "licence", "licence_usable",
    "attribution", "local_path", "sha256", "notes",
]

# CC-BY-NC and CC-BY-NC-SA are fine for a university project and for research,
# and forbid commercial use. Flagging rather than excluding: whether this app
# is "commercial" is the team's call, and it changes with how it is published.
NONCOMMERCIAL = {"CC-BY-NC", "CC-BY-NC-SA"}
FREELY_USABLE = {"CC-BY", "CC-BY-SA", "CC0", "PUBLIC-DOMAIN"}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--candidates", required=True, type=pathlib.Path)
    ap.add_argument("--images-root", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    args = ap.parse_args()

    with args.candidates.open(newline="", encoding="utf-8-sig") as fh:
        raw = list(csv.DictReader(fh))

    print(f"\nReading {args.candidates}")
    print(f"  {len(raw)} manifest rows")
    print("=" * 72)

    rows: list[dict] = []
    unresolved: dict[str, int] = collections.Counter()
    missing_file = 0
    dup_sha = 0
    dup_phash = 0

    seen_sha: dict[str, str] = {}
    seen_phash: dict[str, str] = {}
    # Group id per perceptual hash: visually identical images share a group so
    # the splitter cannot put one copy in train and another in test.
    group_of_phash: dict[str, str] = {}

    for r in raw:
        code = resolve_class(r["seafood_code"])
        if code is None:
            unresolved[r["seafood_code"]] += 1
            continue

        local = (r.get("local_path") or "").strip().replace("\\", "/")
        if not local:
            continue
        # The manifest paths are rooted at "images/"; --images-root points there.
        rel = local[len("images/"):] if local.startswith("images/") else local
        # The corpus was resized for transfer, so extensions may differ.
        path = args.images_root / rel
        if not path.exists():
            alt = path.with_suffix(".jpg")
            if alt.exists():
                path, rel = alt, str(pathlib.Path(rel).with_suffix(".jpg"))
            else:
                missing_file += 1
                continue

        sha = (r.get("sha256") or "").strip()
        phash = (r.get("perceptual_hash") or "").strip()

        if sha and sha in seen_sha:
            dup_sha += 1
            continue
        if phash and phash in seen_phash:
            # Keep it, but bind it to the group of the image it duplicates so
            # the two can never land on opposite sides of a split.
            dup_phash += 1

        if sha:
            seen_sha[sha] = rel
        group = group_of_phash.setdefault(phash or sha or rel, sha[:16] or rel)
        if phash:
            seen_phash.setdefault(phash, rel)

        licence = (r.get("license") or "").strip().upper()
        usable = "YES" if licence in FREELY_USABLE else (
            "REVIEW" if licence in NONCOMMERCIAL else "REVIEW")

        note_bits = [f"source={r.get('source_dataset', '')}"]
        if r.get("source_taxon_match") not in ("EXACT", ""):
            note_bits.append(f"taxon_match={r['source_taxon_match']}")
        if licence in NONCOMMERCIAL:
            note_bits.append("non-commercial licence")

        rows.append({
            "image_id": r.get("image_id", rel),
            "class_code": code,
            "class_label": LABELS[code],
            "scientific_name": r.get("scientific_name", ""),
            # WILD: photographed alive, on a boat, or as a museum specimen —
            # not on a market slab. Kept distinct from RETAIL so the domain gap
            # stays visible in every report rather than being averaged away.
            "domain": "WILD",
            "split": "UNASSIGNED",
            "original_group_id": group,
            "source": r.get("source_dataset", ""),
            "source_url": r.get("source_url", ""),
            "licence": licence,
            "licence_usable": usable,
            "attribution": r.get("attribution") or r.get("creator", ""),
            "local_path": rel,
            "sha256": sha,
            "notes": "; ".join(note_bits),
        })

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=MANIFEST_FIELDS)
        w.writeheader()
        w.writerows(rows)

    per_class = collections.Counter(r["class_code"] for r in rows)
    print(f"\n{'class':<8}{'label':<22}{'images':>8}")
    print("-" * 40)
    for c in CLASSES:
        n = per_class.get(c.class_code, 0)
        flag = "   <-- thin" if n < 60 else ""
        print(f"{c.class_code:<8}{c.label:<22}{n:>8}{flag}")
    print("-" * 40)
    print(f"{'TOTAL':<30}{len(rows):>8}")

    print(f"\nDropped: {dup_sha} byte-identical duplicates, {missing_file} rows "
          f"whose file is absent")
    print(f"Grouped: {dup_phash} visually-identical images pinned to a shared "
          f"group so they cannot straddle a split")

    licences = collections.Counter(r["licence"] for r in rows)
    noncomm = sum(n for lic, n in licences.items() if lic in NONCOMMERCIAL)
    print(f"\nLicences: {dict(licences.most_common())}")
    if noncomm:
        print(f"  {noncomm} of {len(rows)} images are non-commercial (CC-BY-NC*).")
        print("  Fine for coursework and research. If this app is ever published")
        print("  commercially, those images must be retrained out.")

    if unresolved:
        print("\nSpecies in the corpus this model does not cover:")
        for name, n in unresolved.most_common():
            print(f"  {name:<20} {n:>5} rows — {explain_unresolved(name)}")

    counts = [per_class.get(c.class_code, 0) for c in CLASSES]
    if min(counts) and max(counts) / min(counts) > 3:
        print(f"\nClass balance: {min(counts)}–{max(counts)} "
              f"({max(counts) / min(counts):.1f}x imbalance). Class weights are "
              f"applied automatically,")
        print("but the thin classes will still be the weak ones.")

    print(f"\nwrote {args.out}")
    return 0 if rows else 1


if __name__ == "__main__":
    raise SystemExit(main())
