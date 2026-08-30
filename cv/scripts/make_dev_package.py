#!/usr/bin/env python3
"""Build a DEV handoff package so the CV path can be exercised before training.

Why this exists: the backend, the Flutter screen and the QA matrix all need a
working /identify long before there are photographs to train on. This produces a
structurally real package — real ImageNet backbone, real ONNX graph, real
preprocessing, real class map — with an UNTRAINED classifier head.

What it is good for:
    the wiring. Top-3 shape and ordering, canonical mapping, CANDIDATES vs
    LOW_CONFIDENCE, the 413/415/422/503 error matrix, the confirm and
    "None of these" flows, latency.

What it is NOT good for:
    anything about accuracy. The head is randomly initialised, so predictions
    are near-uniform noise and mean nothing at all.

Every safeguard here exists to stop this package being mistaken for a real one:
the model version is stamped UNTRAINED and appears in every API response, the
model card records NOT_TRAINED metrics, and the threshold is null by default so
the API always answers LOW_CONFIDENCE.

    python scripts/make_dev_package.py --out ../backend/cv_package
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

import torch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sukacv.backbone import DEFAULT_BACKBONE, SukaClassifier, preprocessing_for  # noqa: E402
from sukacv.classes import NUM_CLASSES, class_map_json  # noqa: E402
from sukacv.export import check_parity, export_graph  # noqa: E402

VERSION = "cv-i1-DEV-UNTRAINED"

BANNER = """
+---------------------------------------------------------------------+
|  DEV PACKAGE — THE CLASSIFIER IS UNTRAINED                          |
|                                                                     |
|  Predictions are noise. Use this to test wiring, states and error   |
|  handling only. Never present its output as identification, and     |
|  never ship it: the model version is stamped UNTRAINED and shows    |
|  up in every /identify response so this cannot pass unnoticed.      |
+---------------------------------------------------------------------+
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=pathlib.Path, default=pathlib.Path("dev_package"))
    ap.add_argument("--backbone", default=DEFAULT_BACKBONE)
    ap.add_argument("--opset", type=int, default=17)
    ap.add_argument(
        "--threshold", type=float, default=None,
        help="leave unset (the default) and every response is LOW_CONFIDENCE, "
             "which is the honest state for an untrained model. Set something "
             "like 0.15 to also exercise the CANDIDATES branch in the UI.",
    )
    ap.add_argument("--seed", type=int, default=20260822)
    args = ap.parse_args()

    print(BANNER)
    torch.manual_seed(args.seed)

    config = preprocessing_for(args.backbone)
    size = int(config["image_size"])

    # Real pretrained backbone, random head. The backbone being real means
    # latency and preprocessing behave exactly as they will in production.
    model = SukaClassifier(args.backbone, NUM_CLASSES, pretrained=True)
    model.eval()

    args.out.mkdir(parents=True, exist_ok=True)
    onnx_path = args.out / "model.onnx"

    dummy = torch.randn(1, 3, size, size)
    export_graph(model, dummy, onnx_path, opset=args.opset)

    try:
        delta = check_parity(model, dummy, onnx_path)
    except RuntimeError as exc:
        print(f"FAIL: {exc}")
        return 1

    (args.out / "class_map.json").write_text(json.dumps(
        {"model_version": VERSION, "classes": class_map_json()}, indent=2))
    (args.out / "preprocessing.json").write_text(json.dumps(config, indent=2))
    (args.out / "requirements-inference.txt").write_text(
        "onnxruntime>=1.16\nnumpy>=1.26,<2; python_version < \"3.13\"\n"
        "numpy>=2.1; python_version >= \"3.13\"\npillow>=10.0\n")
    (args.out / "model_card.json").write_text(json.dumps({
        "model_version": VERSION,
        "framework": f"onnxruntime (exported from timm/{args.backbone})",
        "artifact": "model.onnx",
        "opset": args.opset,
        "input_contract": config,
        "num_classes": NUM_CLASSES,
        "onnx_parity_max_abs_delta": delta,
        "confidence_threshold": args.threshold,
        "metrics": {"status": "NOT_TRAINED",
                    "note": "randomly initialised head; no validation exists"},
        "training_manifest_uri": None,
        "notes": [
            "DEV PACKAGE. The classifier head is untrained and its predictions "
            "are meaningless. Integration testing only.",
            "Replace with a real package from scripts/export_onnx.py before any "
            "demo that claims to identify fish.",
        ],
    }, indent=2))

    print(f"wrote {args.out}/")
    for f in sorted(args.out.iterdir()):
        print(f"  {f.name:<28} {f.stat().st_size:>10,} bytes")
    print(f"\nonnx parity ok (max |delta| = {delta:.2e})")
    print(f"model_version = {VERSION}")
    if args.threshold is None:
        print("threshold  = null  ->  every response will be LOW_CONFIDENCE")
        print("            (pass --threshold 0.15 to also see the CANDIDATES path)")
    else:
        print(f"threshold  = {args.threshold}  ->  responses may report CANDIDATES")
        print("            Remember: those 'candidates' are still noise.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
