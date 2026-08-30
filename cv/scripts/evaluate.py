#!/usr/bin/env python3
"""Produce the validation evidence that 08 s.10 leaves TBD.

Outputs, per evaluated split:
  - overall accuracy and macro-F1
  - per-class precision / recall / F1 / support
  - confusion matrix
  - top-3 hit rate (the number the UI actually depends on)
  - a threshold sweep, which is where the recommended LOW_CONFIDENCE
    threshold comes from instead of being guessed

    python scripts/evaluate.py --checkpoint artifacts/model_stage_b.pt \
        --manifest data/manifest.csv --root data/images \
        --splits test_clean test_dirty --out artifacts/validation_report.json
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

import numpy as np
import torch
from torch.utils.data import DataLoader

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sukacv.backbone import DEFAULT_BACKBONE, SukaClassifier, preprocessing_for
from sukacv.classes import CLASSES, NUM_CLASSES
from sukacv.data import ManifestDataset, load_manifest


def collect(model, samples, batch_size, workers, config):
    loader = DataLoader(ManifestDataset(samples, augment=False, config=config),
                        batch_size=batch_size, num_workers=workers)
    probs, labels = [], []
    model.eval()
    with torch.inference_mode():
        for x, y in loader:
            probs.append(torch.softmax(model(x), dim=1).numpy())
            labels.append(y.numpy())
    return np.concatenate(probs), np.concatenate(labels)


def per_class(y_true, y_pred):
    out = []
    for c in CLASSES:
        i = c.class_index
        tp = int(((y_pred == i) & (y_true == i)).sum())
        fp = int(((y_pred == i) & (y_true != i)).sum())
        fn = int(((y_pred != i) & (y_true == i)).sum())
        prec = tp / (tp + fp) if tp + fp else 0.0
        rec = tp / (tp + fn) if tp + fn else 0.0
        f1 = 2 * prec * rec / (prec + rec) if prec + rec else 0.0
        out.append({"class_code": c.class_code, "label": c.label,
                    "precision": round(prec, 4), "recall": round(rec, 4),
                    "f1": round(f1, 4), "support": int((y_true == i).sum())})
    return out


def threshold_sweep(probs, y_true):
    """What LOW_CONFIDENCE costs you at each cut-off.

    coverage   = share of images whose top-1 confidence clears the threshold
    precision  = of those, the share that are correct
    A sensible I1 threshold keeps top-1 precision high while leaving coverage
    high enough that the app is not permanently saying "not sure".
    """
    top1 = probs.max(1)
    correct = probs.argmax(1) == y_true
    rows = []
    for t in np.arange(0.30, 0.96, 0.05):
        above = top1 >= t
        cov = float(above.mean())
        prec = float(correct[above].mean()) if above.any() else 0.0
        rows.append({"threshold": round(float(t), 2),
                     "coverage": round(cov, 4),
                     "precision_above_threshold": round(prec, 4),
                     "n_above": int(above.sum())})
    return rows


def evaluate_split(model, manifest, root, split, batch_size, workers, config):
    try:
        samples = load_manifest(manifest, {split}, root)
    except RuntimeError as exc:
        return {"split": split, "status": "NO_DATA", "detail": str(exc)}

    probs, y_true = collect(model, samples, batch_size, workers, config)
    y_pred = probs.argmax(1)
    order = np.argsort(-probs, axis=1)
    top3 = float(np.mean([y_true[i] in order[i, :3] for i in range(len(y_true))]))
    pc = per_class(y_true, y_pred)

    cm = np.zeros((NUM_CLASSES, NUM_CLASSES), dtype=int)
    for t, p in zip(y_true, y_pred):
        cm[t, p] += 1

    return {
        "split": split,
        "status": "OK",
        "n": int(len(y_true)),
        "accuracy": round(float((y_pred == y_true).mean()), 4),
        "macro_f1": round(float(np.mean([r["f1"] for r in pc])), 4),
        "top3_hit_rate": round(top3, 4),
        "per_class": pc,
        "confusion_matrix": {
            "labels": [c.class_code for c in CLASSES],
            "rows_are_true": True,
            "matrix": cm.tolist(),
        },
        "threshold_sweep": threshold_sweep(probs, y_true),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkpoint", required=True, type=pathlib.Path)
    ap.add_argument("--manifest", required=True, type=pathlib.Path)
    ap.add_argument("--root", required=True, type=pathlib.Path)
    ap.add_argument("--backbone", default=DEFAULT_BACKBONE)
    ap.add_argument("--splits", nargs="+", default=["val", "test_clean", "test_dirty"])
    ap.add_argument("--batch-size", type=int, default=16)
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--out", type=pathlib.Path, default=pathlib.Path("artifacts/validation_report.json"))
    args = ap.parse_args()

    # weights come from the checkpoint, so the backbone init does not need to download
    config = preprocessing_for(args.backbone)
    model = SukaClassifier(args.backbone, NUM_CLASSES, pretrained=False)
    model.load_state_dict(torch.load(args.checkpoint, map_location="cpu", weights_only=True))

    report = {"checkpoint": str(args.checkpoint), "backbone": args.backbone, "splits": []}
    for split in args.splits:
        r = evaluate_split(model, args.manifest, args.root, split,
                           args.batch_size, args.workers, config)
        report["splits"].append(r)
        if r["status"] != "OK":
            print(f"\n[{split}] no data — skipped")
            continue
        print(f"\n[{split}] n={r['n']}  acc={r['accuracy']:.4f}  "
              f"macro_f1={r['macro_f1']:.4f}  top3={r['top3_hit_rate']:.4f}")
        print(f"  {'class':<8}{'prec':>8}{'rec':>8}{'f1':>8}{'n':>6}")
        for row in r["per_class"]:
            print(f"  {row['class_code']:<8}{row['precision']:>8.3f}{row['recall']:>8.3f}"
                  f"{row['f1']:>8.3f}{row['support']:>6}")

    # The threshold recommendation is taken from the dirty retail set when it
    # exists, because that is the distribution the app actually sees.
    basis = next((r for r in report["splits"]
                  if r.get("split") == "test_dirty" and r.get("status") == "OK"), None)
    if basis is None:
        basis = next((r for r in report["splits"] if r.get("status") == "OK"), None)

    if basis:
        ok = [row for row in basis["threshold_sweep"]
              if row["precision_above_threshold"] >= 0.85 and row["coverage"] >= 0.60]
        rec = min(ok, key=lambda r: r["threshold"]) if ok else None
        report["recommended_threshold"] = {
            "basis_split": basis["split"],
            "value": rec["threshold"] if rec else None,
            "rule": "lowest threshold with top-1 precision >= 0.85 and coverage >= 0.60",
            "note": ("no threshold met the rule; either the model or the dataset is not "
                     "ready, do not ship a guessed value" if rec is None else
                     "must remain configurable in the backend (08 s.10)"),
        }
        print(f"\nrecommended threshold: {report['recommended_threshold']['value']} "
              f"(from {basis['split']})")
        if basis["split"] != "test_dirty":
            print("WARNING: computed on clean data. A threshold not validated on dirty")
            print("retail images will be wrong in the market. Do not ship it as final.")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2))
    print(f"\nwrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
