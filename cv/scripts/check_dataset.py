#!/usr/bin/env python3
"""Is the dataset ready to train on? Gate 1 from the build plan, as a command.

Exits non-zero until the answer is yes, so it can sit in CI and stop anyone
producing a model from a dataset that cannot support one. Run it after every
ingest — it tells the team exactly what to go photograph next.

Checks, in order of how badly each one hurts:
  1. Per-class training volume against the floor.
  2. Domain mix — a class dominated by museum specimens will not work in a market.
  3. A real held-out dirty retail set, collected separately.
  4. Invalid/unsupported inputs, so LOW_CONFIDENCE behaviour can be measured.
  5. Split leakage — no original photo's derivatives across two splits.
  6. Licence and provenance completeness.
  7. Files that the manifest claims exist.

    python scripts/check_dataset.py --manifest data/manifest.csv --root data/images
"""

from __future__ import annotations

import argparse
import collections
import csv
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sukacv.classes import CLASSES  # noqa: E402

MIN_TRAIN_PER_CLASS = 150
MIN_VAL_PER_CLASS = 30
MIN_DIRTY_PER_CLASS = 30
MIN_INVALID_TOTAL = 40
MIN_RETAIL_SHARE = 0.50  # of each class's training images

TRAIN_SPLITS = {"train"}
CODES = [c.class_code for c in CLASSES]
LABELS = {c.class_code: c.label for c in CLASSES}


class Report:
    def __init__(self) -> None:
        self.failures: list[str] = []
        self.warnings: list[str] = []

    def fail(self, msg: str) -> None:
        self.failures.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)


def load(manifest: pathlib.Path) -> list[dict]:
    with manifest.open(newline="", encoding="utf-8") as fh:
        return [r for r in csv.DictReader(fh) if r.get("licence_usable") != "NO"]


def check_volume(rows: list[dict], rep: Report) -> None:
    print("\nPer-class volume")
    print(f"  {'class':<8}{'label':<22}{'train':>7}{'val':>7}{'clean':>7}"
          f"{'dirty':>7}{'retail%':>9}")
    print("  " + "-" * 67)

    for code in CODES:
        sub = [r for r in rows if r["class_code"] == code]
        counts = collections.Counter(r["split"] for r in sub)
        train = [r for r in sub if r["split"] in TRAIN_SPLITS]
        retail = sum(1 for r in train if r.get("domain") == "RETAIL")
        share = retail / len(train) if train else 0.0

        print(f"  {code:<8}{LABELS[code]:<22}{counts['train']:>7}{counts['val']:>7}"
              f"{counts['test_clean']:>7}{counts['test_dirty']:>7}{share * 100:>8.0f}%")

        if counts["train"] < MIN_TRAIN_PER_CLASS:
            rep.fail(f"{code} has {counts['train']} training images, "
                     f"floor is {MIN_TRAIN_PER_CLASS}")
        if counts["val"] < MIN_VAL_PER_CLASS:
            rep.fail(f"{code} has {counts['val']} validation images, "
                     f"floor is {MIN_VAL_PER_CLASS}")
        if counts["test_dirty"] < MIN_DIRTY_PER_CLASS:
            rep.fail(f"{code} has {counts['test_dirty']} dirty-retail test images, "
                     f"floor is {MIN_DIRTY_PER_CLASS}")
        if train and share < MIN_RETAIL_SHARE:
            rep.fail(f"{code} training set is only {share:.0%} retail imagery; "
                     f"a specimen-dominated class will not survive a market")

    # Imbalance is measured across classes, not within one.
    train_counts = [sum(1 for r in rows
                        if r["class_code"] == c and r["split"] == "train")
                    for c in CODES]
    if min(train_counts) > 0 and max(train_counts) / min(train_counts) > 3:
        rep.warn(f"training set is {max(train_counts) / min(train_counts):.1f}x "
                 f"imbalanced across classes; class weights help but do not "
                 f"replace images")


def check_invalid_set(rows: list[dict], rep: Report) -> None:
    n = sum(1 for r in rows if r["split"] == "test_invalid")
    print(f"\nInvalid / unsupported test inputs: {n}")
    if n < MIN_INVALID_TOTAL:
        rep.fail(f"only {n} test_invalid images, floor is {MIN_INVALID_TOTAL}. "
                 f"Without these, LOW_CONFIDENCE behaviour on fillets, other "
                 f"species and non-fish photos is untested (08 s.8, 09 s.8)")


def check_dirty_independence(rows: list[dict], rep: Report) -> None:
    """The held-out set must be independently collected, not a slice of training."""
    dirty_sources = {r.get("source", "") for r in rows if r["split"] == "test_dirty"}
    train_sources = {r.get("source", "") for r in rows if r["split"] in TRAIN_SPLITS}
    overlap = {s for s in dirty_sources & train_sources if s}
    if overlap:
        rep.warn(f"test_dirty shares collection sources with training: "
                 f"{sorted(overlap)[:3]}. Same market on the same day is closer "
                 f"to a validation split than a held-out test")


def check_leakage(rows: list[dict], rep: Report) -> None:
    groups: dict[str, set[str]] = collections.defaultdict(set)
    for r in rows:
        groups[r["original_group_id"]].add(r["split"])
    leaked = {g: s for g, s in groups.items() if len(s) > 1}
    print(f"\nSplit leakage: {len(leaked)} group(s) spanning multiple splits")
    if leaked:
        for g, s in list(leaked.items())[:5]:
            print(f"  {g} appears in {sorted(s)}")
        rep.fail(f"{len(leaked)} original photo(s) have derivatives in more than "
                 f"one split. Every accuracy number from this dataset is inflated")


def check_provenance(rows: list[dict], rep: Report) -> None:
    no_source = sum(1 for r in rows if not (r.get("source") or "").strip())
    no_licence = sum(1 for r in rows if not (r.get("licence") or "").strip())
    review = sum(1 for r in rows if r.get("licence_usable") == "REVIEW")
    print(f"\nProvenance: {no_source} rows without a source, "
          f"{no_licence} without a licence, {review} awaiting licence review")
    if no_source or no_licence:
        rep.fail(f"{max(no_source, no_licence)} row(s) lack source or licence. "
                 f"09 s.3 requires class, source, licence and group id per image")
    if review:
        rep.warn(f"{review} row(s) are licence_usable=REVIEW and are still being "
                 f"trained on. Resolve them or mark them NO")


def check_files_exist(rows: list[dict], root: pathlib.Path, rep: Report) -> None:
    missing = [r for r in rows
               if (r.get("local_path") or "").strip()
               and not (root / r["local_path"]).exists()]
    no_path = [r for r in rows if not (r.get("local_path") or "").strip()]
    print(f"\nFiles: {len(rows) - len(missing) - len(no_path)} present, "
          f"{len(missing)} missing on disk, {len(no_path)} never downloaded")
    if missing:
        rep.fail(f"{len(missing)} manifest rows point at files that are not in "
                 f"{root}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True, type=pathlib.Path)
    ap.add_argument("--root", required=True, type=pathlib.Path)
    ap.add_argument("--strict", action="store_true",
                    help="treat warnings as failures too")
    args = ap.parse_args()

    rows = load(args.manifest)
    rep = Report()

    print(f"Dataset readiness — {args.manifest} ({len(rows)} usable rows)")
    print("=" * 72)

    check_volume(rows, rep)
    check_invalid_set(rows, rep)
    check_dirty_independence(rows, rep)
    check_leakage(rows, rep)
    check_provenance(rows, rep)
    check_files_exist(rows, args.root, rep)

    print("\n" + "=" * 72)
    if rep.warnings:
        print(f"\n{len(rep.warnings)} warning(s):")
        for w in rep.warnings:
            print(f"  ~ {w}")

    if rep.failures:
        print(f"\n{len(rep.failures)} blocker(s) before Gate 1:")
        for f in rep.failures:
            print(f"  x {f}")
        print("\nNOT READY TO TRAIN. The fastest path through this list is "
              "usually one more market trip, not one more training run.")
        return 1

    if args.strict and rep.warnings:
        print("\nNOT READY (--strict: warnings count as blockers).")
        return 1

    print("\nGate 1 PASSED. The dataset can support a model.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
