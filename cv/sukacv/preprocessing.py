"""Deterministic preprocessing owned by the CV package (08 s.4).

The frontend must NOT reproduce this. The FastAPI adapter imports it, and the
exact parameters ship as preprocessing.json in the handoff package so the
backend can register them in cv_model_version.input_contract.

The transform is intentionally boring: decode -> RGB -> resize shorter side ->
centre crop -> float32 [0,1] -> normalise -> NCHW. No randomness.

Constants are config-driven rather than hard-coded so that a backbone swap
cannot leave inference normalising with the wrong mean/std while training used
the right ones — a bug that shows up as "accuracy was fine in the notebook".
The adapter always builds its Preprocessor from the package's own
preprocessing.json, never from this module's defaults.
"""

from __future__ import annotations

import io
from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageOps

MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 08 s.4
ACCEPTED_FORMATS = {"JPEG", "PNG", "WEBP"}
MIN_SIDE_PX = 32

# Defaults match the default backbone (ImageNet normalisation, 224px).
# sukacv.backbone.preprocessing_for() is the authority at export time.
DEFAULT_CONFIG: dict = {
    "image_size": 224,
    "resize_shorter_side": 256,
    "colour_order": "RGB",
    "scale": "0-1",
    "mean": [0.485, 0.456, 0.406],
    "std": [0.229, 0.224, 0.225],
    "layout": "NCHW",
    "dtype": "float32",
    "interpolation": "bilinear",
    "exif_transpose": True,
    "max_upload_bytes": MAX_UPLOAD_BYTES,
    "accepted_formats": sorted(ACCEPTED_FORMATS),
}


class InvalidImageError(ValueError):
    """Bytes cannot be decoded into a usable image.

    The adapter maps this to INVALID_IMAGE_CONTENT -> HTTP 422 (08 s.8).
    """


def decode(image_bytes: bytes) -> Image.Image:
    """Bytes -> RGB PIL image, or InvalidImageError.

    Format is checked from the decoded bytes, not from the client's
    Content-Type, because a client can claim anything.
    """
    try:
        img = Image.open(io.BytesIO(image_bytes))
        img.load()
    except Exception as exc:  # noqa: BLE001 - any decode failure is the same story
        raise InvalidImageError(f"image could not be decoded: {exc}") from exc

    if img.format not in ACCEPTED_FORMATS:
        raise InvalidImageError(f"unsupported image format: {img.format}")

    img = ImageOps.exif_transpose(img)
    img = img.convert("RGB")

    if min(img.size) < MIN_SIDE_PX:
        raise InvalidImageError(f"image too small to be a usable fish photo: {img.size}")
    return img


@dataclass(frozen=True)
class Preprocessor:
    """Config-bound transform. Build one per model package, reuse it."""

    image_size: int
    resize_shorter_side: int
    mean: tuple[float, float, float]
    std: tuple[float, float, float]

    @classmethod
    def from_config(cls, config: dict | None = None) -> "Preprocessor":
        c = {**DEFAULT_CONFIG, **(config or {})}
        return cls(
            image_size=int(c["image_size"]),
            resize_shorter_side=int(c["resize_shorter_side"]),
            mean=tuple(float(v) for v in c["mean"]),
            std=tuple(float(v) for v in c["std"]),
        )

    def to_tensor(self, img: Image.Image) -> np.ndarray:
        """PIL image -> (1, 3, S, S) float32, ready for the model."""
        w, h = img.size
        scale = self.resize_shorter_side / min(w, h)
        img = img.resize((max(1, round(w * scale)), max(1, round(h * scale))),
                         Image.BILINEAR)

        w, h = img.size
        s = self.image_size
        left, top = (w - s) // 2, (h - s) // 2
        img = img.crop((left, top, left + s, top + s))

        arr = np.asarray(img, dtype=np.float32) / 255.0
        arr = (arr - np.array(self.mean, dtype=np.float32)) / np.array(self.std, dtype=np.float32)
        arr = arr.transpose(2, 0, 1)[None, ...]
        return np.ascontiguousarray(arr, dtype=np.float32)

    def __call__(self, image_bytes: bytes) -> np.ndarray:
        return self.to_tensor(decode(image_bytes))


DEFAULT = Preprocessor.from_config()


def preprocess(image_bytes: bytes) -> np.ndarray:
    """Convenience wrapper on the default config. Training path only."""
    return DEFAULT(image_bytes)
