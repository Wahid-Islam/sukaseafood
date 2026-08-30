#!/usr/bin/env python3
"""Fetch images referenced by manifest source_url, fill in local_path + sha256.

Deduplicates on content hash: two URLs serving identical bytes collapse to one
row, because near-duplicate images inflate accuracy and teach nothing.

Polite by default (1 request/sec, real User-Agent, resumable). Rows that fail
are marked in notes rather than silently dropped, so the failure is visible in
the manifest instead of in a mysterious class imbalance later.

    python scripts/download_images.py --manifest data/manifest_seed.csv \
        --out-dir data/images --manifest-out data/manifest.csv
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import pathlib
import time
import urllib.error
import urllib.request

UA = "SukaSeafood-I1-research/1.0 (university project; contact: <team email>)"
VALID_MAGIC = (b"\xff\xd8\xff", b"\x89PNG\r\n\x1a\n", b"RIFF")


def fetch(url: str, timeout: int) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True, type=pathlib.Path)
    ap.add_argument("--manifest-out", required=True, type=pathlib.Path)
    ap.add_argument("--out-dir", required=True, type=pathlib.Path)
    ap.add_argument("--delay", type=float, default=1.0, help="seconds between requests")
    ap.add_argument("--timeout", type=int, default=30)
    args = ap.parse_args()

    with args.manifest.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        fields = reader.fieldnames or []
        rows = list(reader)

    seen_hashes: dict[str, str] = {}
    ok = skipped = failed = duplicate = 0

    for row in rows:
        if row.get("local_path"):
            skipped += 1
            continue
        url = (row.get("source_url") or "").strip()
        if not url:
            row["notes"] = (row.get("notes", "") + "; no source_url").strip("; ")
            failed += 1
            continue

        try:
            data = fetch(url, args.timeout)
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            row["notes"] = (row.get("notes", "") + f"; DOWNLOAD_FAILED: {exc}").strip("; ")
            failed += 1
            time.sleep(args.delay)
            continue

        if not data.startswith(VALID_MAGIC):
            row["notes"] = (row.get("notes", "") + "; NOT_AN_IMAGE").strip("; ")
            failed += 1
            time.sleep(args.delay)
            continue

        digest = hashlib.sha256(data).hexdigest()
        if digest in seen_hashes:
            row["notes"] = (row.get("notes", "")
                            + f"; EXACT_DUPLICATE of {seen_hashes[digest]}").strip("; ")
            row["licence_usable"] = "NO"  # excluded from training by data.load_manifest
            duplicate += 1
            time.sleep(args.delay)
            continue

        ext = ".jpg" if data[:3] == b"\xff\xd8\xff" else (".png" if data[1:4] == b"PNG" else ".webp")
        rel = f"{row['class_code']}/{digest[:16]}{ext}"
        dest = args.out_dir / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)

        row["local_path"] = rel
        row["sha256"] = digest
        seen_hashes[digest] = rel
        ok += 1
        time.sleep(args.delay)

    args.manifest_out.parent.mkdir(parents=True, exist_ok=True)
    with args.manifest_out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    print(f"downloaded {ok}, already had {skipped}, exact duplicates {duplicate}, failed {failed}")
    print(f"manifest -> {args.manifest_out}")
    if failed:
        print("Failed rows are kept with a DOWNLOAD_FAILED note. Review before training.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
