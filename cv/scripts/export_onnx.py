#!/usr/bin/env python3
"""Freeze a checkpoint into the handoff package described in 08 s.9.

Produces, under --out:
    model.onnx              deployable artifact (opset 17, batch axis dynamic)
    class_map.json          every class_index -> SF00x, the contract's hard requirement
    preprocessing.json      exact input contract for cv_model_version.input_contract
    model_card.json         version string, backbone, metrics slot, threshold slot
    requirements-inference.txt

A model file on its own is not an acceptable handoff (08 s.9), so this script
refuses to emit a package with a missing class map or preprocessing config.

    python scripts/export_onnx.py --checkpoint artifacts/model_stage_b.pt \
        --version cv-i1-2026-08-24 --validation artifacts/validation_report.json
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

import torch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sukacv.backbone import DEFAULT_BACKBONE, SukaClassifier, preprocessing_for
from sukacv.classes import NUM_CLASSES, class_map_json
from sukacv.export import check_parity, export_graph

INFERENCE_REQUIREMENTS = """\
onnxruntime>=1.17
numpy>=1.26
pillow>=10.0
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkpoint", required=True, type=pathlib.Path)
    ap.add_argument("--version", required=True,
                    help="stable model version string, e.g. cv-i1-2026-08-24")
    ap.add_argument("--backbone", default=DEFAULT_BACKBONE)
    ap.add_argument("--validation", type=pathlib.Path,
                    help="validation_report.json from evaluate.py")
    ap.add_argument("--out", type=pathlib.Path, default=pathlib.Path("handoff"))
    ap.add_argument("--opset", type=int, default=17)
    args = ap.parse_args()

    config = preprocessing_for(args.backbone)
    image_size = int(config["image_size"])

    model = SukaClassifier(args.backbone, NUM_CLASSES, pretrained=False)
    model.load_state_dict(torch.load(args.checkpoint, map_location="cpu", weights_only=True))
    model.eval()

    args.out.mkdir(parents=True, exist_ok=True)
    onnx_path = args.out / "model.onnx"

    dummy = torch.randn(1, 3, image_size, image_size)
    export_graph(model, dummy, onnx_path, opset=args.opset)

    # A bad export ships silently otherwise, and the backend ends up serving a
    # different model from the one that was validated.
    try:
        max_delta = check_parity(model, dummy, onnx_path)
    except RuntimeError as exc:
        print(f"FAIL: {exc}")
        return 1

    validation = None
    threshold = None
    if args.validation and args.validation.exists():
        validation = json.loads(args.validation.read_text())
        threshold = (validation.get("recommended_threshold") or {}).get("value")

    (args.out / "class_map.json").write_text(json.dumps({
        "model_version": args.version,
        "classes": class_map_json(),
    }, indent=2))
    (args.out / "preprocessing.json").write_text(json.dumps(config, indent=2))
    (args.out / "requirements-inference.txt").write_text(INFERENCE_REQUIREMENTS)
    (args.out / "model_card.json").write_text(json.dumps({
        "model_version": args.version,
        "framework": f"onnxruntime (exported from torchvision/{args.backbone})",
        "artifact": "model.onnx",
        "opset": args.opset,
        "input_contract": config,
        "num_classes": NUM_CLASSES,
        "onnx_parity_max_abs_delta": max_delta,
        "confidence_threshold": threshold,
        "metrics": validation,
        "training_manifest_uri": None,
        "notes": [
            "confidence values are softmax outputs and are NOT calibrated "
            "probabilities unless a calibration study says otherwise (08 s.5)",
            "user inference images are never persisted or reused for training (08 s.11)",
        ],
    }, indent=2))

    print(f"handoff package written to {args.out}/")
    for f in sorted(args.out.iterdir()):
        print(f"  {f.name:<28} {f.stat().st_size:>10,} bytes")
    print(f"\nonnx parity ok (max |delta| = {max_delta:.2e})")
    if threshold is None:
        print("threshold is null. Backend must not ship until evaluate.py produces one.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
