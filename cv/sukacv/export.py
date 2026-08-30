"""ONNX export, kept in one place so version differences bite once.

torch.onnx.export changed shape across releases:
  - torch < 2.5   has no `dynamo` argument at all; passing it is a TypeError.
  - torch >= 2.6  defaults to the dynamo-based exporter, which produces a
                  different graph from the TorchScript one this project has
                  validated against ONNX Runtime.

Neither "always pass it" nor "never pass it" is right, so ask the signature.
The team runs a spread of torch versions on a spread of machines; the exported
graph must not depend on which one built it.
"""

from __future__ import annotations

import inspect
import pathlib
from typing import Any

import numpy as np
import torch


def supports_dynamo_flag() -> bool:
    """True when this torch build accepts torch.onnx.export(..., dynamo=...)."""
    try:
        return "dynamo" in inspect.signature(torch.onnx.export).parameters
    except (TypeError, ValueError):  # signature unavailable on some builds
        return False


def export_graph(
    model: torch.nn.Module,
    dummy: torch.Tensor,
    path: pathlib.Path | str,
    opset: int = 17,
) -> None:
    """Export the classifier to ONNX with a dynamic batch axis.

    Pins the legacy TorchScript exporter where that choice exists, because it
    is the path whose output has been checked against ONNX Runtime here.
    """
    kwargs: dict[str, Any] = {
        "input_names": ["input"],
        "output_names": ["logits"],
        "dynamic_axes": {"input": {0: "batch"}, "logits": {0: "batch"}},
        "opset_version": opset,
        "do_constant_folding": True,
    }
    if supports_dynamo_flag():
        kwargs["dynamo"] = False

    torch.onnx.export(model, dummy, str(path), **kwargs)


def check_parity(
    model: torch.nn.Module,
    dummy: torch.Tensor,
    path: pathlib.Path | str,
    tolerance: float = 1e-3,
    trials: int = 8,
) -> float:
    """Confirm the exported graph behaves like the torch model.

    Checks probabilities and ranking, not raw logits. A trained network's
    logits can span tens of units — this model reaches -59 — so an absolute
    logit tolerance is meaningless: the same relative float32 error looks
    catastrophic on a large logit and invisible on a small one. What the
    backend actually serves is a softmax and a Top-3 ordering, so that is what
    has to survive the export.

    Ranking is checked too, because probabilities can agree to three decimals
    while two near-tied classes swap places — which would silently change
    which fish the app names first.

    Several random inputs, not one: a single draw can miss a discrepancy that
    only appears in part of the input space.

    Returns the largest absolute probability difference seen.
    """
    import onnxruntime as ort

    session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
    shape = tuple(dummy.shape)
    generator = torch.Generator().manual_seed(20260830)

    worst_prob = 0.0
    worst_logit = 0.0
    for trial in range(trials):
        x = dummy if trial == 0 else torch.randn(shape, generator=generator)
        with torch.inference_mode():
            expected = model(x).numpy()
        actual = session.run(None, {"input": x.numpy()})[0]

        worst_logit = max(worst_logit, float(np.abs(expected - actual).max()))

        p_expected, p_actual = _softmax(expected[0]), _softmax(actual[0])
        worst_prob = max(worst_prob, float(np.abs(p_expected - p_actual).max()))

        k = min(3, len(p_expected))
        if list(np.argsort(-p_expected)[:k]) != list(np.argsort(-p_actual)[:k]):
            raise RuntimeError(
                f"torch and ONNX disagree on the Top-{k} ordering (trial "
                f"{trial}). The export is not faithful — do not ship it."
            )

    if worst_prob > tolerance:
        raise RuntimeError(
            f"torch and ONNX probabilities differ by {worst_prob:.6f} "
            f"(tolerance {tolerance}) across {trials} inputs. The export is "
            f"not faithful — do not ship it."
        )
    return worst_prob


def _softmax(x: np.ndarray) -> np.ndarray:
    e = np.exp(x - x.max())
    return e / e.sum()
