"""Backbone selection, tuned for CPU-only training and CPU-only inference.

Why MobileNetV3-Small by default:
  - ~1.5M parameters in the feature extractor, ~0.06 GFLOPs at 224px. A frozen
    forward pass over a few thousand images is minutes on a laptop CPU.
  - ONNX Runtime serves it in single-digit milliseconds on two CPU cores, which
    keeps POST /api/identify well inside a sane request budget.
  - Partial fine-tuning (last blocks + head) fits in a few hundred MB of RAM.

EfficientNet-B0 is the fallback when the linear probe plateaus and there is
time to spare: ~4x the compute, usually a few points of accuracy.

Weights come from timm, but are loaded from a LOCAL file fetched by
scripts/fetch_weights.py. Neither download.pytorch.org nor huggingface.co is
reachable from this project's network; the timm GitHub release assets are.
Never silently fall back to random initialisation — an untrained backbone
produces a model that looks trained and predicts noise.
"""

from __future__ import annotations

import pathlib

import timm
import torch
import torch.nn as nn

# name -> the timm release asset that carries its ImageNet weights.
# All four use ImageNet mean/std, so preprocessing is identical across them.
BACKBONES: dict[str, dict] = {
    "mobilenetv3_small_100": {"weights_file": "mobilenetv3_small_100_lamb-266a294c.pth"},
    "mobilenetv3_large_100": {"weights_file": "mobilenetv3_large_100_ra-f55367f5.pth"},
    "efficientnet_b0": {"weights_file": "efficientnet_b0_ra-3dd342df.pth"},
}

DEFAULT_BACKBONE = "mobilenetv3_small_100"
WEIGHTS_DIR = pathlib.Path(__file__).resolve().parents[1] / "weights"


class WeightsMissingError(RuntimeError):
    """Pretrained weights are not on disk. Run scripts/fetch_weights.py."""


def weights_path(name: str) -> pathlib.Path:
    return WEIGHTS_DIR / BACKBONES[name]["weights_file"]


def build_feature_extractor(
    name: str = DEFAULT_BACKBONE, pretrained: bool = True
) -> tuple[nn.Module, int]:
    """Backbone with the classifier stripped. Returns (module, embed_dim).

    pretrained=False exists only for offline plumbing tests. ImageNet weights
    are the entire reason a five-class model is trainable on a few hundred
    images; never train a real model with them off.
    """
    if name not in BACKBONES:
        raise ValueError(f"unknown backbone {name!r}; choose from {sorted(BACKBONES)}")

    model = timm.create_model(name, pretrained=False, num_classes=0)

    if pretrained:
        path = weights_path(name)
        if not path.exists():
            raise WeightsMissingError(
                f"{path} not found.\n"
                f"Run:  python scripts/fetch_weights.py --backbone {name}\n"
                f"Training without ImageNet weights produces a model that looks "
                f"trained and predicts noise, so this is a hard failure."
            )
        state = torch.load(path, map_location="cpu", weights_only=True)
        missing, unexpected = model.load_state_dict(state, strict=False)
        # The classifier head is expected to be unexpected (num_classes=0).
        real_missing = [k for k in missing if not k.startswith("classifier.")]
        if real_missing:
            raise RuntimeError(
                f"weights at {path.name} do not match {name}: "
                f"{len(real_missing)} missing keys, first is {real_missing[0]}"
            )

    model.eval()
    # Probe the real output width rather than hard-coding it. timm's
    # num_features is the pre-head channel count, which is NOT what a
    # num_classes=0 model actually emits for every architecture.
    with torch.no_grad():
        size = model.default_cfg["input_size"][-1]
        embed_dim = int(model(torch.zeros(1, 3, size, size)).shape[-1])
    return model, embed_dim


def preprocessing_for(name: str = DEFAULT_BACKBONE) -> dict:
    """The exact input contract this backbone was trained with (08 s.4).

    Read from timm's own config rather than hard-coded, so a backbone swap can
    never leave the adapter normalising with the wrong constants.
    """
    cfg = timm.create_model(name, pretrained=False).default_cfg
    size = cfg["input_size"][-1]
    return {
        "backbone": name,
        "image_size": size,
        "resize_shorter_side": int(round(size / cfg.get("crop_pct", 0.875))),
        "colour_order": "RGB",
        "scale": "0-1",
        "mean": list(cfg["mean"]),
        "std": list(cfg["std"]),
        "layout": "NCHW",
        "dtype": "float32",
        "interpolation": "bilinear",
        "exif_transpose": True,
        "max_upload_bytes": 10 * 1024 * 1024,
        "accepted_formats": ["JPEG", "PNG", "WEBP"],
    }


class SukaClassifier(nn.Module):
    """Backbone + linear head. The exported ONNX graph is exactly this module."""

    def __init__(self, backbone_name: str, num_classes: int, pretrained: bool = True):
        super().__init__()
        self.backbone_name = backbone_name
        self.backbone, embed_dim = build_feature_extractor(backbone_name, pretrained)
        self.embed_dim = embed_dim
        self.head = nn.Linear(embed_dim, num_classes)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.head(self.backbone(x))  # logits; softmax happens in the adapter

    def freeze_backbone(self) -> None:
        for p in self.backbone.parameters():
            p.requires_grad = False

    def trainable_backbone_params(self):
        """Stage B: only the final feature blocks, kept as one place to change.

        On CPU this is the difference between a fine-tune that finishes over
        lunch and one that does not finish at all.
        """
        blocks = getattr(self.backbone, "blocks", None)
        if blocks is None:
            raise RuntimeError(f"{self.backbone_name} has no .blocks to unfreeze")
        return list(blocks[-2:].parameters())

    def unfreeze_last_block(self) -> None:
        for p in self.trainable_backbone_params():
            p.requires_grad = True
