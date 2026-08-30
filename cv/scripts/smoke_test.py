#!/usr/bin/env python3
"""End-to-end smoke test on synthetic images.

Proves the pipeline runs on CPU before a single real photograph exists:
manifest -> split -> stage A train -> evaluate -> ONNX export -> adapter.

The "fish" here are coloured noise patterns. Accuracy numbers from this run
are meaningless and must never appear in a handoff document. What it verifies
is plumbing: shapes, splits, export parity, error codes.

    python scripts/smoke_test.py --workdir /tmp/suka_smoke
"""

from __future__ import annotations

import argparse
import csv
import io
import pathlib
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sukacv.classes import CLASSES  # noqa: E402

MANIFEST_FIELDS = [
    "image_id", "class_code", "class_label", "scientific_name", "domain", "split",
    "original_group_id", "source", "source_url", "licence", "licence_usable",
    "attribution", "local_path", "sha256", "notes",
]


def synth(seed: int, class_index: int, size: int = 320) -> Image.Image:
    """A per-class deterministic texture, so a linear probe can actually learn it."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    freq = 3 + class_index * 4
    base = np.sin(freq * np.pi * xx + class_index) * np.cos(freq * np.pi * yy)
    img = np.zeros((size, size, 3), dtype=np.float32)
    for c in range(3):
        tint = 0.35 + 0.3 * ((class_index + c) % 3)
        img[..., c] = tint + 0.25 * base + rng.normal(0, 0.05, (size, size))
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


def build(workdir: pathlib.Path, per_class: int) -> pathlib.Path:
    images = workdir / "images"
    images.mkdir(parents=True, exist_ok=True)
    rows = []
    for c in CLASSES:
        for i in range(per_class):
            rel = f"{c.class_code}/{c.class_code}_{i:03d}.jpg"
            (images / c.class_code).mkdir(exist_ok=True)
            synth(c.class_index * 1000 + i, c.class_index).save(images / rel, quality=92)
            # last few of each class become the "dirty retail" held-out set
            split = "test_dirty" if i >= per_class - 3 else "UNASSIGNED"
            rows.append({
                "image_id": rel, "class_code": c.class_code, "class_label": c.label,
                "scientific_name": c.scientific_name, "domain": "SYNTHETIC", "split": split,
                "original_group_id": f"{c.class_code}-{i:03d}", "source": "smoke_test",
                "source_url": "", "licence": "CC0", "licence_usable": "YES",
                "attribution": "synthetic", "local_path": rel, "sha256": "",
                "notes": "synthetic smoke-test image, never for training a real model",
            })
    manifest = workdir / "manifest.csv"
    with manifest.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=MANIFEST_FIELDS)
        w.writeheader()
        w.writerows(rows)
    return manifest


def run(step: str, cmd: list[str]) -> None:
    print(f"\n{'=' * 68}\n{step}\n{'=' * 68}")
    r = subprocess.run(cmd, cwd=ROOT)
    if r.returncode != 0:
        raise SystemExit(f"FAILED: {step}")


def check_adapter(package: pathlib.Path, workdir: pathlib.Path) -> None:
    print(f"\n{'=' * 68}\n6. adapter contract\n{'=' * 68}")
    from sukacv.adapter import CvAdapter, ImageTooLargeError
    from sukacv.preprocessing import InvalidImageError

    adapter = CvAdapter(package_dir=package)
    sample = next((workdir / "images").rglob("*.jpg"))
    out = adapter.predict(sample.read_bytes())

    assert out["status"] in {"CANDIDATES", "LOW_CONFIDENCE"}, out["status"]
    assert len(out["predictions"]) == 3, "adapter must return Top 3, not Top 1 (08 s.5)"
    conf = [p["confidence"] for p in out["predictions"]]
    assert conf == sorted(conf, reverse=True), "predictions must be sorted descending"
    assert all(p["class_code"].startswith("SF") for p in out["predictions"])
    assert out["model_version"], "model_version must be present in every response"
    print(f"  status={out['status']}  model_version={out['model_version']}  "
          f"threshold={out['threshold']}")
    for p in out["predictions"]:
        print(f"    rank {p['rank']}  {p['class_code']}  {p['confidence']:.4f}")

    for name, payload, exc in [
        ("oversized upload -> 413", b"x" * (10 * 1024 * 1024 + 1), ImageTooLargeError),
        ("garbage bytes -> 422", b"not an image at all", InvalidImageError),
        ("1x1 pixel -> 422", _tiny_png(), InvalidImageError),
    ]:
        try:
            adapter.predict(payload)
        except exc:
            print(f"  ok: {name}")
        else:
            raise SystemExit(f"FAILED: {name} did not raise {exc.__name__}")


def _tiny_png() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (8, 8), "red").save(buf, format="PNG")
    return buf.getvalue()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--workdir", type=pathlib.Path, default=pathlib.Path("/tmp/suka_smoke"))
    ap.add_argument("--per-class", type=int, default=14)
    ap.add_argument("--no-pretrained", action="store_true",
                    help="run without downloading ImageNet weights (offline CI)")
    args = ap.parse_args()

    args.workdir.mkdir(parents=True, exist_ok=True)
    print(f"1. synthesising {args.per_class * len(CLASSES)} images -> {args.workdir}")
    manifest = build(args.workdir, args.per_class)

    run("2. split_manifest.py", [sys.executable, "scripts/split_manifest.py",
                                 "--manifest", str(manifest), "--out", str(manifest)])
    run("3. train.py --stage a", [sys.executable, "scripts/train.py", "--stage", "a",
                                  "--manifest", str(manifest),
                                  "--root", str(args.workdir / "images"),
                                  "--out", str(args.workdir / "artifacts"),
                                  "--head-epochs", "60", "--workers", "0",
                                  *(["--no-pretrained"] if args.no_pretrained else [])])
    run("4. evaluate.py", [sys.executable, "scripts/evaluate.py",
                           "--checkpoint", str(args.workdir / "artifacts/model_stage_a.pt"),
                           "--manifest", str(manifest),
                           "--root", str(args.workdir / "images"),
                           "--splits", "val", "test_clean", "test_dirty",
                           "--workers", "0",
                           "--out", str(args.workdir / "artifacts/validation_report.json")])
    run("5. export_onnx.py", [sys.executable, "scripts/export_onnx.py",
                              "--checkpoint", str(args.workdir / "artifacts/model_stage_a.pt"),
                              "--version", "cv-i1-smoke-test",
                              "--validation", str(args.workdir / "artifacts/validation_report.json"),
                              "--out", str(args.workdir / "handoff")])
    check_adapter(args.workdir / "handoff", args.workdir)

    print(f"\n{'=' * 68}")
    print("SMOKE TEST PASSED — the pipeline runs end to end on CPU.")
    print("Accuracy figures above are from synthetic textures and mean nothing.")
    print(f"{'=' * 68}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
