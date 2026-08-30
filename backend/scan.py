#!/usr/bin/env python3
"""Scan one or more fish photographs from the command line.

    ./run.sh --scan photo.jpg
    ./run.sh --scan ~/Downloads/sukaseafood-fish-images/images/*/*/*.jpg

The shortest path from "is the computer vision working?" to an answer. No
server, no curl, no database — this loads the ONNX artifact and the frozen
class map directly, which is the right scope when the question is about the
model rather than the API around it.

Two things it prints that a bare prediction would not:

  * the full Top-3 with confidences, because the app never shows only the
    top answer — a shopper picks from the list, and a scanner that is right
    second is far more useful than one that is wrong first
  * whether the result cleared the confidence threshold, so a low-confidence
    answer is visibly low-confidence rather than looking like a firm one
  * the expected species, when the file sits under a corpus folder named for
    one, so the output is scoreable instead of merely plausible

Exits non-zero if the model package is missing or an image cannot be read, so
it also works as a smoke test in a script.
"""

from __future__ import annotations

import argparse
import pathlib
import sys


def find_package(explicit: str | None) -> pathlib.Path:
    """Locate the model package, preferring an explicit path."""
    here = pathlib.Path(__file__).resolve().parent
    candidates = [pathlib.Path(explicit)] if explicit else [
        here / "cv_package",          # installed for serving
        here.parent / "cv" / "handoff",  # straight from the CV package
    ]
    for path in candidates:
        if (path / "model.onnx").is_file():
            return path

    print("error: no model package found. Looked in:", file=sys.stderr)
    for path in candidates:
        print(f"         {path}", file=sys.stderr)
    print("\n       Install the trained model with:", file=sys.stderr)
    print("           cp -r ../cv/handoff cv_package", file=sys.stderr)
    raise SystemExit(2)


def main() -> int:
    ap = argparse.ArgumentParser(description="Scan fish photographs.")
    ap.add_argument("images", nargs="+", type=pathlib.Path)
    ap.add_argument("--package", help="model package directory")
    ap.add_argument("--threshold", type=float, default=None,
                    help="override the model's own confidence threshold")
    args = ap.parse_args()

    package = find_package(args.package)

    # The CV package lives beside backend/, and is imported without a build step.
    cv_root = pathlib.Path(__file__).resolve().parent.parent / "cv"
    if cv_root.is_dir():
        sys.path.insert(0, str(cv_root))

    try:
        from sukacv.adapter import CvAdapter
        from sukacv.classes import CLASSES
    except ImportError as exc:
        print(f"error: cannot import the CV package ({exc}).", file=sys.stderr)
        print(f"       Expected it at {cv_root}", file=sys.stderr)
        return 2

    adapter = CvAdapter(package_dir=package, threshold=args.threshold)

    # The adapter deliberately returns class_code only — it never learns a
    # human-readable name, let alone a seafood_item_id. Names are for this
    # display; the API resolves codes to canonical rows through the database.
    labels = {c.class_code: c.label for c in CLASSES}

    print(f"model    {adapter.model_version}")
    print(f"package  {package}")
    if "UNTRAINED" in adapter.model_version.upper():
        print("\n  ** This is a DEV package. The classifier is UNTRAINED and its")
        print("  ** predictions are noise. Integration testing only.")
    print()

    # When the file sits under a corpus folder named for a species
    # (.../images/TENGGIRI/...), that folder is the ground truth. Showing it
    # turns a list of predictions into a scoreable result, and stops the most
    # natural mistake with this tool: scanning one species' folder, seeing that
    # species win every time, and reading it as a bias in the model.
    folders = {c.dataset_dir.upper(): c.class_code for c in CLASSES}

    def expected_code(path: pathlib.Path) -> str | None:
        for part in path.resolve().parts:
            if part.upper() in folders:
                return folders[part.upper()]
        return None

    failures = 0
    scored = hits = 0
    for image in args.images:
        if not image.is_file():
            print(f"{image}: not a file", file=sys.stderr)
            failures += 1
            continue

        try:
            result = adapter.predict(image.read_bytes())
        except Exception as exc:  # the adapter's own typed errors
            print(f"{image.name}: {type(exc).__name__}: {exc}", file=sys.stderr)
            failures += 1
            continue

        state = result["status"]
        top = result["predictions"][0]["class_code"]

        want = expected_code(image)
        if want is None:
            verdict = ""
            marker = "?" if state == "LOW_CONFIDENCE" else " "
        else:
            scored += 1
            correct = want == top
            hits += correct
            verdict = f"   expected {want} {labels[want]}  -> {'OK' if correct else 'MISS'}"
            marker = "." if correct else "X"

        print(f"{marker} {image.name}{verdict}")
        for p in result["predictions"]:
            bar = "#" * round(p["confidence"] * 30)
            label = labels.get(p["class_code"], "?")
            print(f"    {p['rank']}. {p['class_code']}  {label:<24} "
                  f"{p['confidence']:.3f}  {bar}")
        if state == "LOW_CONFIDENCE":
            print("    below the confidence threshold — the app would show these as")
            print("    candidates to choose from, not as an identification")
        print()

    if scored:
        print(f"{hits}/{scored} correct  ({hits / scored:.0%})")
        seen = {expected_code(i) for i in args.images if i.is_file()}
        seen.discard(None)
        if len(seen) == 1:
            only = seen.pop()
            print(f"\nNote: every image here is {only} {labels[only]}, so that class")
            print("winning every time is the model being right, not a bias. To see it")
            print("discriminate, scan across folders:")
            print("    ./run.sh --scan <corpus>/images/*/*/*.jpg")
    if failures:
        print(f"{failures} image(s) could not be scanned", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
