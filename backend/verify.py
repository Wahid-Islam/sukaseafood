#!/usr/bin/env python3
"""Answer "is this working?" end to end, and say precisely what is not.

    ./run.sh --verify

Starts a scratch server on a free port, exercises the API including the whole
CV error matrix and the scan-to-canonical-id chain, prints PASS/FAIL per check
and a one-word verdict, then cleans up after itself. Exits non-zero if anything
is broken, so it works in CI as well as by hand.

It reports honestly in both directions. With no model package installed it
expects and checks for the 503 rather than calling that a failure, and it says
so in the verdict — "the API is fine, the scanner is not installed" is a
different situation from "the scanner is broken", and conflating them wastes an
afternoon.
"""

from __future__ import annotations

import io
import pathlib
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = pathlib.Path(__file__).resolve().parent
PY = sys.executable

checks: list[tuple[bool, str, str]] = []


def check(ok: bool, name: str, detail: str = "") -> bool:
    checks.append((ok, name, detail))
    print(f"  [{'PASS' if ok else 'FAIL'}] {name}" + (f"  {detail}" if detail else ""))
    return ok


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def request(url: str, data: bytes | None = None, headers: dict | None = None):
    """Return (status, parsed_json_or_text). HTTP errors are results, not raises."""
    import json

    req = urllib.request.Request(url, data=data, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            body = r.read()
            status = r.status
    except urllib.error.HTTPError as e:
        body, status = e.read(), e.code
    except Exception as e:  # noqa: BLE001
        return 0, str(e)
    try:
        return status, json.loads(body)
    except ValueError:
        return status, body.decode("utf-8", "replace")


def multipart(field: str, filename: str, blob: bytes, content_type: str):
    boundary = "----sukaverify"
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="{field}"; filename="{filename}"\r\n'
        f"Content-Type: {content_type}\r\n\r\n"
    ).encode() + blob + f"\r\n--{boundary}--\r\n".encode()
    return body, {"Content-Type": f"multipart/form-data; boundary={boundary}"}


def jpeg(colour=(120, 130, 140), size=(224, 224)) -> bytes:
    from PIL import Image

    buf = io.BytesIO()
    Image.new("RGB", size, colour).save(buf, format="JPEG")
    return buf.getvalue()


def main() -> int:
    port = free_port()
    base = f"http://127.0.0.1:{port}/api/v1"
    has_model = (HERE / "cv_package" / "model.onnx").is_file()

    print(f"\nstarting a scratch server on port {port}")
    server = subprocess.Popen(
        [PY, "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", str(port)],
        cwd=HERE, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT,
    )
    try:
        for _ in range(60):
            if request(f"{base}/health")[0] == 200:
                break
            if server.poll() is not None:
                print("\nerror: the server exited during startup. Run ./run.sh to see why.",
                      file=sys.stderr)
                return 1
            time.sleep(0.5)
        else:
            print("\nerror: the server never became reachable.", file=sys.stderr)
            return 1

        print("\nCore API")
        status, body = request(f"{base}/health")
        check(status == 200 and body.get("status") == "ok", "GET /health")

        status, body = request(f"{base}/health/db")
        db_ok = status == 200 and body.get("schema_applied") is True
        check(db_ok, "GET /health/db  schema applied",
              f"{body.get('seafood_count')} species" if db_ok else str(body)[:80])

        status, items = request(f"{base}/seafood")
        check(status == 200 and isinstance(items, list) and len(items) == 15,
              "GET /seafood returns the catalogue",
              f"{len(items) if isinstance(items, list) else '?'} items")

        status, body = request(f"{base}/search?q=kembung")
        found = status == 200 and any(r["fish_id"] == "SF001" for r in body.get("results", []))
        check(found, "GET /search?q=kembung resolves via alias")

        status, body = request(f"{base}/seafood/SF001")
        check(status == 200 and body.get("aliases") and body.get("cooking"),
              "GET /seafood/SF001 has aliases and cooking")

        print("\nComputer vision")
        if not has_model:
            status, body = request(f"{base}/identify", *multipart("file", "f.jpg", jpeg(), "image/jpeg"))
            code = (body.get("detail", {}) or {}).get("error", {}).get("code") \
                if isinstance(body, dict) else None
            check(status == 503 and code == "MODEL_UNAVAILABLE",
                  "no model installed -> 503 MODEL_UNAVAILABLE", "as designed")
        else:
            # --- error matrix, before any successful call ---
            body_, hdr = multipart("file", "notes.txt", b"not a fish", "text/plain")
            status, _ = request(f"{base}/identify", body_, hdr)
            check(status == 415, "POST /identify wrong type -> 415")

            body_, hdr = multipart("file", "huge.jpg", b"\xff\xd8\xff" + b"\x00" * (12 << 20), "image/jpeg")
            status, _ = request(f"{base}/identify", body_, hdr)
            check(status == 413, "POST /identify over 10 MB -> 413")

            body_, hdr = multipart("file", "bad.jpg", b"\xff\xd8\xff\xe0" + b"junk" * 50, "image/jpeg")
            status, _ = request(f"{base}/identify", body_, hdr)
            check(status == 422, "POST /identify corrupt image -> 422")

            # --- the real path ---
            body_, hdr = multipart("file", "f.jpg", jpeg(), "image/jpeg")
            status, body = request(f"{base}/identify", body_, hdr)
            ok = check(status == 200 and isinstance(body, dict), "POST /identify -> 200")

            if ok:
                cands = body.get("candidates", [])
                check(1 <= len(cands) <= 3, "returns up to 3 candidates", f"{len(cands)}")
                confs = [c["confidence"] for c in cands]
                check(confs == sorted(confs, reverse=True), "candidates sorted by confidence")
                check([c["rank"] for c in cands] == list(range(1, len(cands) + 1)),
                      "ranks are 1..n")
                check(body.get("status") in {"CANDIDATES", "LOW_CONFIDENCE"},
                      "status is a business state", str(body.get("status")))
                check(body.get("confirmation_required") is True,
                      "confirmation_required is true  (top-1 never auto-finalised)")
                check(body.get("image_persisted") is False,
                      "image_persisted is false  (uploads are never stored)")

                version = body.get("model_version", "")
                if "UNTRAINED" in version.upper():
                    check(False, "model is the UNTRAINED dev package",
                          "predictions are noise — replace with cv/handoff")
                else:
                    check(True, "trained model loaded", version)

                # --- the chain that makes the scanner useful ---
                if cands:
                    top = cands[0]
                    valid = True
                    try:
                        uuid.UUID(str(top["seafood_item_id"]))
                    except (ValueError, KeyError, TypeError):
                        valid = False
                    check(valid, "candidate carries a canonical seafood_item_id",
                          str(top.get("seafood_item_id"))[:36])

                    s1, p1 = request(f"{base}/seafood/{top['seafood_item_id']}")
                    s2, p2 = request(f"{base}/seafood/{top['code']}")
                    check(s1 == 200, "that id resolves to a profile")
                    check(s1 == 200 and s2 == 200 and p1 == p2,
                          "scanned id and searched code are the same row")
                    check(s1 == 200 and bool(p1.get("aliases")) and bool(p1.get("cooking")),
                          "the profile reaches the joined tables",
                          "aliases + cooking + sustainability")

                    unscannable = {"SF003", "SF004", "SF005"}
                    check(not ({c["code"] for c in cands} & unscannable),
                          "no unscannable species returned")

        print("\n" + "=" * 60)
        failed = [c for c in checks if not c[0]]
        if not failed:
            if not has_model:
                print(f"API WORKING — all {len(checks)} checks passed.")
                print("The scanner is not installed. To install the trained model:")
                print("    cp -r ../cv/handoff cv_package")
                return 0
            print(f"WORKING — all {len(checks)} checks passed.")
            return 0

        print(f"BROKEN — {len(failed)} of {len(checks)} checks failed:")
        for _, name, detail in failed:
            print(f"    {name}" + (f"  ({detail})" if detail else ""))
        return 1

    finally:
        server.terminate()
        try:
            server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            server.kill()


if __name__ == "__main__":
    raise SystemExit(main())
