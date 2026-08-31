"""End-to-end smoke test of the two endpoints the app gained in this round.

Checks the shapes the Flutter client actually parses, including the error
envelopes: the scan and price screens branch on `MODEL_UNAVAILABLE` and
`FORECAST_UNAVAILABLE` codes, so an error that loses its code degrades a normal
product state into a generic failure message on the phone.

Usage (backend already running):
    python scripts/smoke_api.py [base_url]
"""

from __future__ import annotations

import io
import json
import sys
import urllib.error
import urllib.request
import uuid

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000/api/v1"


def get(path: str) -> tuple[int, dict]:
    try:
        with urllib.request.urlopen(f"{BASE}{path}", timeout=60) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as exc:
        body = exc.read()
        try:
            return exc.code, json.loads(body)
        except ValueError:
            return exc.code, {"raw": body.decode("utf-8", "replace")}


def post_image(path: str, image: bytes, filename: str, content_type: str) -> tuple[int, dict]:
    boundary = f"----suka{uuid.uuid4().hex}"
    body = io.BytesIO()
    body.write(f"--{boundary}\r\n".encode())
    body.write(
        f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'.encode()
    )
    body.write(f"Content-Type: {content_type}\r\n\r\n".encode())
    body.write(image)
    body.write(f"\r\n--{boundary}--\r\n".encode())

    request = urllib.request.Request(
        f"{BASE}{path}",
        data=body.getvalue(),
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        try:
            return exc.code, json.loads(raw)
        except ValueError:
            return exc.code, {"raw": raw.decode("utf-8", "replace")}


def error_code(payload: dict) -> str | None:
    detail = payload.get("detail")
    if isinstance(detail, dict):
        error = detail.get("error")
        if isinstance(error, dict):
            return error.get("code")
    return None


def synthetic_jpeg() -> bytes:
    """A plain generated image. The prediction is meaningless, but it proves the
    upload, decode, preprocess, ONNX session and class-map join all work."""
    from PIL import Image, ImageDraw

    image = Image.new("RGB", (640, 480), (28, 74, 96))
    draw = ImageDraw.Draw(image)
    draw.ellipse((120, 170, 520, 310), fill=(176, 186, 194))
    draw.polygon([(520, 240), (610, 175), (610, 305)], fill=(176, 186, 194))
    draw.ellipse((185, 220, 205, 240), fill=(20, 20, 20))

    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=90)
    return buffer.getvalue()


def main() -> int:
    failures: list[str] = []

    status, payload = get("/health")
    print(f"GET  /health                       {status} {payload}")
    if status != 200:
        failures.append("health")

    status, payload = get("/seafood/SF001/forecast")
    weeks = payload.get("forecast", []) if status == 200 else []
    print(f"GET  /seafood/SF001/forecast       {status} weeks={len(weeks)}")
    if status != 200 or len(weeks) != 4:
        failures.append("forecast SF001")

    status, payload = get("/seafood/SF004/forecast")
    code = error_code(payload)
    print(f"GET  /seafood/SF004/forecast       {status} code={code}")
    if status != 404 or code != "FORECAST_UNAVAILABLE":
        failures.append("forecast unavailable envelope")

    status, payload = get("/seafood/SF999/forecast")
    code = error_code(payload)
    print(f"GET  /seafood/SF999/forecast       {status} code={code}")
    if status != 404 or code != "SEAFOOD_NOT_FOUND":
        failures.append("unknown seafood envelope")

    status, payload = post_image("/identify", synthetic_jpeg(), "probe.jpg", "image/jpeg")
    if status == 200:
        candidates = payload.get("candidates", [])
        print(f"POST /identify                     {status} "
              f"model={payload.get('model_version')} candidates={len(candidates)}")
        for candidate in candidates[:3]:
            print(f"       #{candidate.get('rank')} {candidate.get('code')} "
                  f"{candidate.get('display_name_en')} {candidate.get('confidence')}")
        if not candidates:
            failures.append("identify returned no candidates")
    else:
        print(f"POST /identify                     {status} code={error_code(payload)} {payload}")
        failures.append("identify")

    status, payload = post_image("/identify", b"not an image", "probe.txt", "text/plain")
    print(f"POST /identify (bad type)          {status} code={error_code(payload)}")
    if status not in (400, 415):
        failures.append("identify should reject non-images")

    print()
    if failures:
        print("FAILED:", ", ".join(failures))
        return 1
    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
