"""The CV adapter FastAPI imports (08 s.2, s.5).

Boundary, restated because it is the thing most likely to be violated:
  - This module returns ranked class_code + confidence. Nothing else.
  - It does NOT know about seafood ids. Canonical mapping is the backend's job,
    driven by cv_model_label rows, so the model can be swapped without touching
    the public API.
  - It does NOT decide identity. The user does, after confirmation.

Load once per process (08 s.12), not once per request.
"""

from __future__ import annotations

import json
import pathlib
import threading
from dataclasses import dataclass, field
from typing import Any, Literal

import numpy as np

from .preprocessing import (  # noqa: F401 - InvalidImageError is re-exported on purpose
    MAX_UPLOAD_BYTES,
    InvalidImageError,
    Preprocessor,
)

Status = Literal["CANDIDATES", "LOW_CONFIDENCE"]

TOP_K = 3


class ModelUnavailableError(RuntimeError):
    """Adapter could not load or run. Backend maps this to 503 MODEL_UNAVAILABLE."""


class ImageTooLargeError(ValueError):
    """Backend maps this to 413 IMAGE_TOO_LARGE."""


@dataclass
class Prediction:
    rank: int
    class_code: str
    confidence: float

    def as_dict(self) -> dict[str, Any]:
        return {"rank": self.rank, "class_code": self.class_code,
                "confidence": round(self.confidence, 4)}


@dataclass
class CvAdapter:
    """ONNX Runtime adapter. Thread-safe for the single-session CPU case."""

    package_dir: pathlib.Path
    threshold: float | None = None
    intra_op_threads: int = 2
    _session: Any = field(default=None, init=False, repr=False)
    _lock: threading.Lock = field(default_factory=threading.Lock, init=False, repr=False)
    _pre: Preprocessor = field(default=None, init=False, repr=False)
    _index_to_code: dict[int, str] = field(default_factory=dict, init=False)
    model_version: str = field(default="", init=False)

    def __post_init__(self) -> None:
        self.package_dir = pathlib.Path(self.package_dir)
        self._load()

    # -- loading -----------------------------------------------------------
    def _load(self) -> None:
        _check_runtime_compatibility()
        try:
            import onnxruntime as ort
        except ImportError as exc:
            raise ModelUnavailableError("onnxruntime is not installed") from exc

        class_map_path = self.package_dir / "class_map.json"
        model_path = self.package_dir / "model.onnx"
        prep_path = self.package_dir / "preprocessing.json"
        card_path = self.package_dir / "model_card.json"

        # "A model file by itself is not an acceptable handoff" (08 s.9).
        for p in (model_path, class_map_path, prep_path):
            if not p.exists():
                raise ModelUnavailableError(
                    f"handoff package at {self.package_dir} is incomplete: "
                    f"missing {p.name}"
                )

        class_map = json.loads(class_map_path.read_text())
        self.model_version = class_map["model_version"]
        self._index_to_code = {c["class_index"]: c["class_code"] for c in class_map["classes"]}

        expected = set(range(len(class_map["classes"])))
        if set(self._index_to_code) != expected:
            raise ModelUnavailableError(
                f"class map indices {sorted(self._index_to_code)} are not contiguous "
                f"from 0; refusing to guess class order (08 s.11)"
            )

        # Preprocessing comes from the package, never from module defaults, so
        # a model trained with different normalisation cannot be served wrong.
        self._pre = Preprocessor.from_config(json.loads(prep_path.read_text()))

        if self.threshold is None and card_path.exists():
            self.threshold = json.loads(card_path.read_text()).get("confidence_threshold")

        try:
            opts = ort.SessionOptions()
            opts.intra_op_num_threads = self.intra_op_threads  # one request must not eat the box
            self._session = ort.InferenceSession(
                str(model_path), sess_options=opts, providers=["CPUExecutionProvider"]
            )
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(f"could not load {model_path.name}: {exc}") from exc

        n_out = self._session.get_outputs()[0].shape[-1]
        if isinstance(n_out, int) and n_out != len(self._index_to_code):
            raise ModelUnavailableError(
                f"model emits {n_out} logits but class map has "
                f"{len(self._index_to_code)} classes"
            )

    # -- inference ---------------------------------------------------------
    def predict(self, image_bytes: bytes) -> dict[str, Any]:
        """The contract call (08 s.5).

        Returns:
            {"model_version": str,
             "status": "CANDIDATES" | "LOW_CONFIDENCE",
             "threshold": float | None,
             "predictions": [{"rank": 1, "class_code": "SF001", "confidence": 0.82}, ...]}

        Raises:
            ImageTooLargeError    -> 413
            InvalidImageError     -> 422
            ModelUnavailableError -> 503
        """
        if len(image_bytes) > MAX_UPLOAD_BYTES:
            raise ImageTooLargeError(
                f"image is {len(image_bytes)} bytes, limit is {MAX_UPLOAD_BYTES}"
            )

        tensor = self._pre(image_bytes)  # raises InvalidImageError

        if self._session is None:
            raise ModelUnavailableError("inference session is not loaded")
        try:
            with self._lock:
                logits = self._session.run(None, {"input": tensor})[0][0]
        except Exception as exc:  # noqa: BLE001
            raise ModelUnavailableError(f"inference failed: {exc}") from exc

        probs = _softmax(logits)
        order = np.argsort(-probs)[:TOP_K]
        predictions = [
            Prediction(rank=i + 1,
                       class_code=self._index_to_code[int(idx)],
                       confidence=float(probs[idx]))
            for i, idx in enumerate(order)
        ]

        # A null threshold means validation has not produced one yet. Treat
        # every result as low confidence rather than inventing a cut-off —
        # the UI still shows candidates, it just never implies certainty.
        top1 = predictions[0].confidence if predictions else 0.0
        if self.threshold is None:
            status: Status = "LOW_CONFIDENCE"
        else:
            status = "CANDIDATES" if top1 >= self.threshold else "LOW_CONFIDENCE"

        return {
            "model_version": self.model_version,
            "status": status,
            "threshold": self.threshold,
            "predictions": [p.as_dict() for p in predictions],
        }


def _check_runtime_compatibility() -> None:
    """Refuse a combination that would crash the process instead of raising.

    onnxruntime below 1.19 is compiled against NumPy 1.x. Importing it under
    NumPy 2 does not raise — it aborts the interpreter with a segfault after
    printing '_ARRAY_API not found', which is close to undebuggable inside a
    web server.

    onnxruntime's version is read from package metadata rather than by
    importing it, because the import is the thing that crashes.
    """
    from importlib.metadata import PackageNotFoundError, version

    try:
        ort_version = version("onnxruntime")
    except PackageNotFoundError:
        return  # not installed; the ImportError path gives a better message

    def parse(v: str) -> tuple[int, ...]:
        out = []
        for part in v.split("."):
            digits = "".join(c for c in part if c.isdigit())
            if not digits:
                break
            out.append(int(digits))
        return tuple(out)

    if parse(ort_version)[:2] < (1, 19) and parse(np.__version__)[:1] >= (2,):
        raise ModelUnavailableError(
            f"onnxruntime {ort_version} is built against NumPy 1.x and will "
            f"crash the process on import under NumPy {np.__version__}.\n"
            f"Install a compatible pair — either\n"
            f"    pip install 'numpy<2'\n"
            f"or, if your platform has wheels for it,\n"
            f"    pip install 'onnxruntime>=1.19'\n"
            f"(macOS 12 and earlier cannot go past onnxruntime 1.16.3, so use "
            f"the NumPy 1.x route there.)"
        )


def _softmax(x: np.ndarray) -> np.ndarray:
    e = np.exp(x - x.max())
    return e / e.sum()
