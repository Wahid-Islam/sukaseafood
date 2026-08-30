#!/usr/bin/env python3
"""Assign splits to the dataset manifest, group-aware and stratified.

Two rules the contract cares about (08 s.9, 09 s.3):
  1. Every derivative of one original photograph stays in ONE split. We split
     on original_group_id, never on rows.
  2. The dirty retail test set is never used for training or tuning. Rows
     already marked split=test_dirty or test_invalid are left untouched.

Usage:
    python split_manifest.py --manifest data/manifest.csv --out data/manifest.csv \
        --val-frac 0.15 --test-frac 0.15 --seed 20260822
"""

from __future__ import annotations

import argparse
import collections
import csv
import pathlib
import random

HELD_OUT = {"test_dirty", "test_invalid"}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    ap.add_argument("--val-frac", type=float, default=0.15)
    ap.add_argument("--test-frac", type=float, default=0.15)
    ap.add_argument("--seed", type=int, default=20260822)
    args = ap.parse_args()

    with args.manifest.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        fields = reader.fieldnames or []
        rows = list(reader)

    assignable = [r for r in rows if r.get("split", "") not in HELD_OUT]
    frozen = [r for r in rows if r.get("split", "") in HELD_OUT]

    # group -> class (a group is one original photo, so it has one class)
    groups: dict[str, str] = {}
    for r in assignable:
        groups[r["original_group_id"]] = r["class_code"]

    by_class: dict[str, list[str]] = collections.defaultdict(list)
    for gid, code in groups.items():
        by_class[code].append(gid)

    rng = random.Random(args.seed)
    assignment: dict[str, str] = {}
    for code, gids in by_class.items():
        gids = sorted(gids)
        rng.shuffle(gids)
        n = len(gids)
        n_val = max(1, round(n * args.val_frac)) if n >= 3 else 0
        n_test = max(1, round(n * args.test_frac)) if n >= 3 else 0
        for i, gid in enumerate(gids):
            if i < n_test:
                assignment[gid] = "test_clean"
            elif i < n_test + n_val:
                assignment[gid] = "val"
            else:
                assignment[gid] = "train"

    for r in assignable:
        r["split"] = assignment[r["original_group_id"]]

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    # Report, and fail loudly on the two things that silently ruin a model.
    counts: dict[tuple[str, str], int] = collections.Counter(
        (r["class_code"], r["split"]) for r in rows
    )
    splits = ["train", "val", "test_clean", "test_dirty", "test_invalid"]
    print(f"{'class':<8}" + "".join(f"{s:>13}" for s in splits))
    print("-" * (8 + 13 * len(splits)))
    for code in sorted({r["class_code"] for r in rows}):
        print(f"{code:<8}" + "".join(f"{counts[(code, s)]:>13}" for s in splits))

    leaks = _group_leaks(rows)
    if leaks:
        print(f"\nFAIL: {len(leaks)} group(s) appear in more than one split: {leaks[:5]}")
        return 1
    print(f"\nOK: {len(groups) + len(frozen)} groups, no group spans two splits.")
    if not any(r["split"] == "test_dirty" for r in rows):
        print("WARN: no test_dirty rows. Retail evaluation is not possible yet (09 s.3).")
    return 0


def _group_leaks(rows: list[dict]) -> list[str]:
    seen: dict[str, set[str]] = collections.defaultdict(set)
    for r in rows:
        seen[r["original_group_id"]].add(r["split"])
    return [gid for gid, s in seen.items() if len(s) > 1]


if __name__ == "__main__":
    raise SystemExit(main())
