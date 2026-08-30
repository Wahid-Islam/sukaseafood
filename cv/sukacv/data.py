"""Manifest-backed dataset. The manifest is the authority, not the folder layout.

Every sample carries its licence and provenance, so a training run can be
audited later: "which images produced this model, and were we allowed to use
them?" (09 s.3).
"""

from __future__ import annotations

import csv
import pathlib
from dataclasses import dataclass

import numpy as np
import torch
from torch.utils.data import Dataset

from .classes import CODE_TO_INDEX
from .preprocessing import DEFAULT_CONFIG, Preprocessor, decode


@dataclass
class Sample:
    local_path: pathlib.Path
    class_index: int
    class_code: str
    group_id: str
    domain: str
    split: str


def load_manifest(path: pathlib.Path, splits: set[str], root: pathlib.Path) -> list[Sample]:
    out: list[Sample] = []
    skipped_missing = 0
    with path.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            if row.get("split") not in splits:
                continue
            if row.get("licence_usable") == "NO":
                continue
            local = (row.get("local_path") or "").strip()
            if not local:
                continue
            p = root / local
            if not p.exists():
                skipped_missing += 1
                continue
            out.append(Sample(
                local_path=p,
                class_index=CODE_TO_INDEX[row["class_code"]],
                class_code=row["class_code"],
                group_id=row["original_group_id"],
                domain=row.get("domain", ""),
                split=row["split"],
            ))
    if skipped_missing:
        print(f"  note: {skipped_missing} manifest rows point at files that are "
              f"not under {root} and were skipped")
    if not out:
        raise RuntimeError(
            f"no usable rows in {path} for splits={sorted(splits)}. "
            "Have the images been downloaded and local_path filled in?"
        )
    return out


class ManifestDataset(Dataset):
    """Deterministic path: identical to what the adapter does at inference."""

    def __init__(self, samples: list[Sample], augment: bool = False,
                 config: dict | None = None):
        self.samples = samples
        self.config = {**DEFAULT_CONFIG, **(config or {})}
        self.pre = Preprocessor.from_config(self.config)
        self._aug = _build_augmentation(self.config) if augment else None

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, i: int) -> tuple[torch.Tensor, int]:
        s = self.samples[i]
        img = decode(s.local_path.read_bytes())
        if self._aug is not None:
            return self._aug(img), s.class_index
        return torch.from_numpy(self.pre.to_tensor(img)[0]), s.class_index


def _build_augmentation(config: dict):
    """Augmentation that matches how people photograph fish on a market slab.

    Deliberately excluded: vertical flip (fish are photographed belly-down, so
    it teaches an orientation that never occurs), heavy rotation, and cutout —
    all of which produce images the model will never see and cost CPU time we
    do not have.
    """
    from torchvision import transforms as T

    size = int(config["image_size"])
    return T.Compose([
        T.RandomResizedCrop(size, scale=(0.65, 1.0), ratio=(0.75, 1.33)),
        T.RandomHorizontalFlip(),
        T.RandomApply([T.ColorJitter(0.3, 0.3, 0.25, 0.04)], p=0.8),   # stall lighting
        T.RandomApply([T.GaussianBlur(5, sigma=(0.1, 1.5))], p=0.2),   # phone shake
        T.RandomRotation(12, expand=False),
        T.ToTensor(),
        T.Normalize(config["mean"], config["std"]),
    ])


def class_weights(samples: list[Sample], num_classes: int) -> torch.Tensor:
    """Inverse-frequency weights. The seed data is ~9x imbalanced toward SF005."""
    counts = np.bincount([s.class_index for s in samples], minlength=num_classes)
    counts = np.maximum(counts, 1)
    w = counts.sum() / (num_classes * counts)
    return torch.tensor(w, dtype=torch.float32)


def describe(samples: list[Sample]) -> str:
    """One-line composition summary, printed before every training run."""
    from collections import Counter
    by_class = Counter(s.class_code for s in samples)
    by_domain = Counter(s.domain for s in samples)
    return (f"{len(samples)} images | "
            f"classes {dict(sorted(by_class.items()))} | "
            f"domains {dict(sorted(by_domain.items()))}")
