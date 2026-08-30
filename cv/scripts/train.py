#!/usr/bin/env python3
"""Two-stage CPU training for the SukaSeafood I1 five-class model.

Stage A (linear probe) — freeze the ImageNet backbone, cache one embedding per
image, fit a linear head. Cost: one forward pass over the dataset, then seconds
per head fit. This is the baseline that tells you whether the *dataset* is the
problem before you spend a day fine-tuning.

Stage B (partial fine-tune) — unfreeze the last feature block and train it with
the head at a low LR. Only worth running once Stage A is on real retail images
and has stopped improving.

    python scripts/train.py --stage a --manifest data/manifest.csv --root data/images
    python scripts/train.py --stage b --manifest data/manifest.csv --root data/images --epochs 8
"""

from __future__ import annotations

import argparse
import json
import pathlib
import time

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader

import sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sukacv.backbone import DEFAULT_BACKBONE, SukaClassifier, preprocessing_for
from sukacv.classes import NUM_CLASSES
from sukacv.data import ManifestDataset, class_weights, describe, load_manifest


def embed_split(model: SukaClassifier, samples, batch_size: int, workers: int, config):
    """One deterministic forward pass -> cached embeddings. Stage A only."""
    loader = DataLoader(ManifestDataset(samples, augment=False, config=config),
                        batch_size=batch_size, shuffle=False, num_workers=workers)
    feats, labels = [], []
    with torch.inference_mode():
        for x, y in loader:
            feats.append(model.backbone(x).cpu().numpy())
            labels.append(y.numpy())
    return np.concatenate(feats), np.concatenate(labels)


def stage_a(args, model, train_s, val_s, config) -> dict:
    print(f"Stage A: embedding {len(train_s)} train / {len(val_s)} val images...")
    t0 = time.time()
    xt, yt = embed_split(model, train_s, args.batch_size, args.workers, config)
    xv, yv = embed_split(model, val_s, args.batch_size, args.workers, config)
    print(f"  embeddings done in {time.time() - t0:.1f}s  dim={xt.shape[1]}")

    head = model.head
    opt = torch.optim.AdamW(head.parameters(), lr=args.lr, weight_decay=args.weight_decay)
    lossf = nn.CrossEntropyLoss(weight=class_weights(train_s, NUM_CLASSES),
                                label_smoothing=0.05)
    xt_t, yt_t = torch.from_numpy(xt), torch.from_numpy(yt).long()
    xv_t, yv_t = torch.from_numpy(xv), torch.from_numpy(yv).long()

    best, best_state = -1.0, None
    for epoch in range(args.head_epochs):
        head.train()
        perm = torch.randperm(len(xt_t))
        for i in range(0, len(perm), args.batch_size):
            idx = perm[i:i + args.batch_size]
            opt.zero_grad()
            loss = lossf(head(xt_t[idx]), yt_t[idx])
            loss.backward()
            opt.step()
        head.eval()
        with torch.inference_mode():
            acc = (head(xv_t).argmax(1) == yv_t).float().mean().item()
        if acc > best:
            best, best_state = acc, {k: v.clone() for k, v in head.state_dict().items()}
        if epoch % 20 == 0 or epoch == args.head_epochs - 1:
            print(f"  epoch {epoch:>3}  loss {loss.item():.4f}  val_acc {acc:.4f}")
    head.load_state_dict(best_state)
    return {"stage": "a", "val_accuracy": best, "train_n": len(train_s), "val_n": len(val_s)}


def stage_b(args, model, train_s, val_s, config) -> dict:
    print(f"Stage B: fine-tuning last block, {len(train_s)} train images, "
          f"{args.epochs} epochs on CPU. This is the slow one.")
    model.unfreeze_last_block()
    params = [p for p in model.parameters() if p.requires_grad]
    print(f"  trainable params: {sum(p.numel() for p in params):,}")

    train_loader = DataLoader(ManifestDataset(train_s, augment=True, config=config),
                              batch_size=args.batch_size, shuffle=True,
                              num_workers=args.workers, drop_last=len(train_s) > args.batch_size)
    val_loader = DataLoader(ManifestDataset(val_s, augment=False, config=config),
                            batch_size=args.batch_size, num_workers=args.workers)

    opt = torch.optim.AdamW([
        {"params": model.trainable_backbone_params(), "lr": args.lr * 0.1},
        {"params": model.head.parameters(), "lr": args.lr},
    ], weight_decay=args.weight_decay)
    sched = torch.optim.lr_scheduler.CosineAnnealingLR(opt, T_max=args.epochs)
    lossf = nn.CrossEntropyLoss(weight=class_weights(train_s, NUM_CLASSES),
                                label_smoothing=0.05)

    best, best_state = -1.0, None
    for epoch in range(args.epochs):
        model.train()
        t0, total = time.time(), 0.0
        for x, y in train_loader:
            opt.zero_grad()
            loss = lossf(model(x), y)
            loss.backward()
            opt.step()
            total += loss.item()
        sched.step()

        model.eval()
        correct = n = 0
        with torch.inference_mode():
            for x, y in val_loader:
                correct += (model(x).argmax(1) == y).sum().item()
                n += len(y)
        acc = correct / max(n, 1)
        print(f"  epoch {epoch + 1}/{args.epochs}  loss {total / max(len(train_loader), 1):.4f}  "
              f"val_acc {acc:.4f}  ({time.time() - t0:.0f}s)")
        if acc > best:
            best, best_state = acc, {k: v.clone() for k, v in model.state_dict().items()}
    model.load_state_dict(best_state)
    return {"stage": "b", "val_accuracy": best, "train_n": len(train_s), "val_n": len(val_s)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage", choices=["a", "b"], required=True)
    ap.add_argument("--manifest", required=True, type=pathlib.Path)
    ap.add_argument("--root", required=True, type=pathlib.Path)
    ap.add_argument("--backbone", default=DEFAULT_BACKBONE)
    ap.add_argument("--out", type=pathlib.Path, default=pathlib.Path("artifacts"))
    ap.add_argument("--init-from", type=pathlib.Path, help="checkpoint to warm-start stage b")
    ap.add_argument("--batch-size", type=int, default=16)
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--epochs", type=int, default=8)
    ap.add_argument("--head-epochs", type=int, default=200)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--weight-decay", type=float, default=1e-4)
    ap.add_argument("--threads", type=int, default=0, help="torch CPU threads; 0 = auto")
    ap.add_argument("--no-pretrained", action="store_true",
                    help="offline plumbing tests only; never for a real model")
    args = ap.parse_args()

    if args.threads:
        torch.set_num_threads(args.threads)
    torch.manual_seed(20260822)

    train_s = load_manifest(args.manifest, {"train"}, args.root)
    val_s = load_manifest(args.manifest, {"val"}, args.root)
    print(f"train: {describe(train_s)}")
    print(f"val:   {describe(val_s)}")

    config = preprocessing_for(args.backbone)

    model = SukaClassifier(args.backbone, NUM_CLASSES, pretrained=not args.no_pretrained)
    if args.no_pretrained:
        print("WARNING: backbone is randomly initialised. Plumbing test only.")
    model.freeze_backbone()
    if args.init_from:
        model.load_state_dict(torch.load(args.init_from, map_location="cpu"))
        print(f"warm-started from {args.init_from}")

    result = stage_a(args, model, train_s, val_s, config) if args.stage == "a" \
        else stage_b(args, model, train_s, val_s, config)

    args.out.mkdir(parents=True, exist_ok=True)
    ckpt = args.out / f"model_stage_{args.stage}.pt"
    torch.save(model.state_dict(), ckpt)
    result["backbone"] = args.backbone
    result["checkpoint"] = str(ckpt)
    (args.out / f"train_stage_{args.stage}.json").write_text(json.dumps(result, indent=2))

    print(f"\nsaved {ckpt}   best val_accuracy={result['val_accuracy']:.4f}")
    print("val_accuracy is a development signal only. The number that goes in the")
    print("handoff comes from scripts/evaluate.py on the held-out dirty retail set.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
