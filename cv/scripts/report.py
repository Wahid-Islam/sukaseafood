#!/usr/bin/env python3
"""Turn validation_report.json into something you can act on.

Ranks the five fish worst-first, because the ranking's job is to tell you what
to go photograph next. Shows the confusion matrix as pairs — "SF003 was called
SF005 eleven times" is actionable in a way a grid of numbers is not.

    python scripts/report.py --validation artifacts/validation_report.json
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sukacv.classes import CLASSES, NOT_YET_SCANNABLE, NUM_CLASSES  # noqa: E402

LABELS = {c.class_code: c.label for c in CLASSES}
BOLD, DIM, RESET = ("\033[1m", "\033[2m", "\033[0m") if sys.stdout.isatty() else ("", "", "")


def bar(value: float, width: int = 20) -> str:
    filled = int(round(value * width))
    return "#" * filled + "." * (width - filled)


def pick(report: dict) -> dict | None:
    """Prefer dirty retail, then clean test, then validation.

    Order matters: test_dirty is the only split that resembles what the app
    will actually see, so it outranks the flattering ones.
    """
    for name in ("test_dirty", "test_clean", "val"):
        for split in report.get("splits", []):
            if split.get("split") == name and split.get("status") == "OK":
                return split
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--validation", required=True, type=pathlib.Path)
    ap.add_argument("--version", default="")
    args = ap.parse_args()

    if not args.validation.exists():
        print(f"no validation report at {args.validation}")
        return 1

    report = json.loads(args.validation.read_text())
    split = pick(report)
    if split is None:
        print("No split produced results. Nothing to report.")
        return 1

    name = split["split"]
    print("=" * 70)
    print(f"{BOLD}MODEL REPORT{RESET}" + (f"   {args.version}" if args.version else ""))
    print("=" * 70)

    honesty = {
        "test_dirty": "held-out market photos — the number that counts",
        "test_clean": "held-out clean photos — optimistic; no dirty set exists yet",
        "val": "VALIDATION split — used for model selection, so this flatters "
               "the model. Collect a test set.",
    }[name]
    print(f"\nMeasured on: {name}  ({split['n']} images)")
    print(f"{DIM}{honesty}{RESET}")

    print(f"\n  overall accuracy   {split['accuracy']:.1%}")
    print(f"  macro F1           {split['macro_f1']:.3f}")
    print(f"  {BOLD}top-3 hit rate     {split['top3_hit_rate']:.1%}{RESET}"
          f"   {DIM}<- what the app depends on{RESET}")

    # Worst first: this list is a photography to-do list.
    print(f"\n{BOLD}Per fish, weakest first{RESET}")
    print(f"  {'':<8}{'':<22}{'recall':>8}  {'':<20} {'prec':>6}{'n':>6}")
    rows = sorted(split["per_class"], key=lambda r: r["recall"])
    for r in rows:
        print(f"  {r['class_code']:<8}{LABELS[r['class_code']]:<22}"
              f"{r['recall']:>7.1%}  {bar(r['recall'])} "
              f"{r['precision']:>6.2f}{r['support']:>6}")

    weakest = rows[0]
    if weakest["recall"] < 0.7:
        print(f"\n  {weakest['class_code']} {LABELS[weakest['class_code']]} is the "
              f"weak one. More images of it, in the")
        print("  conditions where it fails, will move this number further than "
              "more epochs.")

    # Confusion as pairs, biggest first.
    cm = split["confusion_matrix"]
    codes, matrix = cm["labels"], cm["matrix"]
    pairs = [
        (matrix[i][j], codes[i], codes[j])
        for i in range(len(codes)) for j in range(len(codes))
        if i != j and matrix[i][j] > 0
    ]
    pairs.sort(reverse=True)
    if pairs:
        print(f"\n{BOLD}Most common confusions{RESET}")
        for count, true_code, pred_code in pairs[:6]:
            print(f"  {count:>3}x  {true_code} {LABELS[true_code]:<20} "
                  f"called  {pred_code} {LABELS[pred_code]}")

    # Threshold.
    rec = report.get("recommended_threshold") or {}
    print(f"\n{BOLD}LOW_CONFIDENCE threshold{RESET}")
    if rec.get("value") is None:
        print(f"  none recommended — {rec.get('note', 'no qualifying cut-off')}")
        print(f"  {DIM}The API will answer LOW_CONFIDENCE for everything, which is")
        print(f"  the honest state until the model earns a threshold.{RESET}")
    else:
        print(f"  {rec['value']}   (from {rec.get('basis_split', '?')})")
        print(f"  {DIM}{rec.get('rule', '')}{RESET}")
        if rec.get("basis_split") != "test_dirty":
            print("  Computed on clean data. Not final until a dirty retail set exists.")

    # Verdict. Top-3 alone is not enough to judge on: with only five classes,
    # a model that never predicts one of them still scores high top-3 while
    # being useless for that fish. A dead class outranks a good headline.
    print("\n" + "=" * 70)
    top3 = split["top3_hit_rate"]
    acc = split["accuracy"]
    dirty = name == "test_dirty"
    dead = [r for r in rows if r["recall"] < 0.5]
    thin = [r for r in rows if r["support"] < 10]

    if dead:
        names = ", ".join(f"{r['class_code']} {LABELS[r['class_code']]}" for r in dead)
        print(f"{BOLD}Not ready — {len(dead)} of {NUM_CLASSES} fish are recognised "
              f"less than half the time.{RESET}")
        print(f"{names}")
        print(f"\nOverall accuracy of {acc:.0%} hides this, and so does the "
              f"{top3:.0%} top-3: a fish")
        print(f"the model rarely predicts still rides along inside {NUM_CLASSES} "
              f"classes' worth of")
        print("top-3 slots. Fix the confusions listed above before trusting any "
              "headline number.")
    elif top3 >= 0.90 and acc >= 0.75 and dirty:
        print(f"{BOLD}Good enough to demo.{RESET} The right fish is in the top 3 "
              f"{top3:.0%} of the time on")
        print("held-out market photos, every class is being recognised, and the "
              "user picks")
        print("from those three.")
    elif top3 >= 0.90 and acc >= 0.75:
        print(f"{BOLD}Promising{RESET} — top-3 {top3:.0%}, accuracy {acc:.0%}, "
              f"every class alive. But this is")
        print(f"{name}, not held-out market photos. Collect a dirty retail test "
              f"set before")
        print("quoting these numbers anywhere.")
    elif top3 >= 0.75:
        print(f"{BOLD}Usable, not finished.{RESET} Top-3 {top3:.0%}, accuracy "
              f"{acc:.0%}. The weakest classes")
        print("above are where the next batch of photographs should go.")
    else:
        print(f"{BOLD}Not ready.{RESET} Top-3 {top3:.0%} means the right fish is "
              f"often not even offered.")
        print("This is almost always a dataset problem, not a training problem.")

    if thin:
        print(f"\n{DIM}Note: {', '.join(r['class_code'] for r in thin)} scored on "
              f"fewer than 10 images each.")
        print(f"Percentages on that little data move several points per image.{RESET}")

    if NOT_YET_SCANNABLE:
        print(f"\n{DIM}Not scannable at all — canonical rows exist, no training "
              f"images:")
        for code, name in NOT_YET_SCANNABLE.items():
            print(f"  {code}  {name}")
        print(f"They carry supports_cv=false, so /identify never offers them.{RESET}")
    print("=" * 70)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
