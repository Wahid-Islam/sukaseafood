#!/usr/bin/env python3
"""Fetch ImageNet backbone weights into cv/weights/.

Why this script exists: torchvision fetches from download.pytorch.org and timm
fetches from huggingface.co, and BOTH are blocked on this project's network.
The timm GitHub release assets are reachable, so that is where we pull from.
Run this once per machine before the first training run.

    python scripts/fetch_weights.py                    # the default backbone
    python scripts/fetch_weights.py --all              # every supported backbone
    python scripts/fetch_weights.py --backbone efficientnet_b0

If your network blocks GitHub too, download the file listed below on any
machine and drop it in cv/weights/ by hand — nothing else needs to change.
"""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import ssl
import sys
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from sukacv.backbone import BACKBONES, DEFAULT_BACKBONE, WEIGHTS_DIR  # noqa: E402

BASE_URL = "https://github.com/rwightman/pytorch-image-models/releases/download/v0.1-weights"
UA = "SukaSeafood-I1-research/1.0"


def ssl_contexts() -> list[tuple[str, ssl.SSLContext | None]]:
    """Candidate TLS trust stores, tried in order.

    Neither store is right everywhere:
      - The interpreter's default carries a corporate proxy's CA, which is what
        a TLS-intercepting network needs. certifi's bundle does not have it.
      - A fresh virtualenv can have no usable store at all — notably a
        python.org install on macOS before 'Install Certificates.command' has
        been run — where certifi's bundle is the only one that works.

    Trying both costs one extra request on failure and removes a whole class of
    "works on my machine".
    """
    out: list[tuple[str, ssl.SSLContext | None]] = [("system trust store", None)]
    try:
        import certifi
        out.append(("certifi bundle", ssl.create_default_context(cafile=certifi.where())))
    except ImportError:
        pass
    return out


def fetch(name: str, force: bool) -> bool:
    filename = BACKBONES[name]["weights_file"]
    dest = WEIGHTS_DIR / filename
    url = f"{BASE_URL}/{filename}"

    if dest.exists() and not force:
        print(f"  {name:<24} already present ({dest.stat().st_size:,} bytes)")
        return True

    print(f"  {name:<24} fetching {filename} ...")
    req = urllib.request.Request(url, headers={"User-Agent": UA})

    data = None
    last_error: Exception | None = None
    for label, ctx in ssl_contexts():
        try:
            with urllib.request.urlopen(req, timeout=180, context=ctx) as r:
                data = r.read()
            break
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            last_error = exc
            if "CERTIFICATE_VERIFY_FAILED" in str(exc):
                print(f"  {'':<24} {label} rejected it, trying the next store")
                continue
            break  # not a trust problem; another store will not help

    if data is None:
        print(f"  {name:<24} FAILED: {last_error}")
        if "CERTIFICATE_VERIFY_FAILED" in str(last_error):
            print(f"  {'':<24} Every available trust store rejected the connection.")
            print(f"  {'':<24} Try:  python -m pip install --upgrade certifi")
            print(f"  {'':<24} On a python.org install for macOS, also run")
            print(f"  {'':<24}   /Applications/Python\\ 3.x/Install\\ Certificates.command")
        print(f"  {'':<24} Or download by hand from:")
        print(f"  {'':<24}   {url}")
        print(f"  {'':<24} and save it to:")
        print(f"  {'':<24}   {dest}")
        return False

    # timm embeds an 8-hex-char prefix of the file's sha256 in the filename.
    expected = filename.rsplit("-", 1)[-1].removesuffix(".pth")
    actual = hashlib.sha256(data).hexdigest()[:len(expected)]
    if expected != actual:
        print(f"  {name:<24} FAILED: hash mismatch "
              f"(filename says {expected}, file is {actual})")
        return False

    WEIGHTS_DIR.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    print(f"  {name:<24} ok, {len(data):,} bytes, sha256 prefix {actual} verified")
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--backbone", default=DEFAULT_BACKBONE, choices=sorted(BACKBONES))
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--force", action="store_true", help="re-download even if present")
    args = ap.parse_args()

    names = sorted(BACKBONES) if args.all else [args.backbone]
    print(f"weights directory: {WEIGHTS_DIR}")
    results = [fetch(n, args.force) for n in names]

    if not all(results):
        print("\nSome weights are missing. Training will refuse to run without them.")
        return 1
    print("\nAll requested weights present.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
