"""Epic 4 — AI photos for generated recipes.

A recipe card gets an `image_url` the moment its text is generated, but the
photo itself is made lazily, on the first GET of that URL:

    /recipes/images/<image_id>.jpg?t=<signed token>

Why lazy and URL-driven rather than generated inside POST /recipes/generate:

  * The recipe text comes back in seconds; three photos take far longer. The
    client can show the recipes and let each photo fill in (or pre-load them
    while its progress card is still showing).
  * The token carries everything needed to make the photo (fish, title,
    description), so any instance can serve it. Cloud Run may route the GET to
    a different instance than the POST, and an in-memory job table would miss.
  * The token is HMAC-signed with JWT_SECRET, so only URLs this server issued
    can spend OpenAI credit. Nobody can ask the endpoint to draw arbitrary
    prompts.

Generated photos are cached on disk by image_id; a second request is free.
"""

from __future__ import annotations

import asyncio
import base64
import hashlib
import hmac
import json
import logging
import pathlib
import re

from app.config import get_settings
from app.services import openai_client

logger = logging.getLogger(__name__)

BACKEND_DIR = pathlib.Path(__file__).resolve().parents[2]
_IMAGE_ID = re.compile(r"^[a-f0-9]{20}$")

# One generation per image_id at a time, per process. A carousel that asks for
# the same photo twice (e.g. pre-cache plus render) must not pay twice.
_inflight: dict[str, asyncio.Task[bytes]] = {}


class InvalidImageToken(ValueError):
    """The URL was not issued by this server or has been tampered with."""


def enabled() -> bool:
    settings = get_settings()
    return settings.openai_enabled and settings.recipe_images_enabled


def image_id_for(fish_id: str, title: str) -> str:
    normalised_title = re.sub(r"\s+", " ", title.strip().lower())
    key = f"{fish_id.strip().upper()}|{normalised_title}"
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:20]


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _unb64(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def _sign(body: bytes) -> str:
    secret = get_settings().jwt_secret.encode("utf-8")
    return _b64(hmac.new(secret, b"recipe-image:" + body, hashlib.sha256).digest()[:18])


def image_path(
    *,
    fish_id: str,
    fish_name: str,
    fish_name_en: str,
    title: str,
    description: str,
    cooking_method: str | None,
) -> str:
    """The URL (relative to the API base) the client loads the photo from."""
    image_id = image_id_for(fish_id, title)
    body = json.dumps(
        {
            "i": image_id,
            "f": fish_name,
            "e": fish_name_en,
            "t": title[:120],
            "d": description[:240],
            "m": (cooking_method or "")[:20],
        },
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
    token = f"{_b64(body)}.{_sign(body)}"
    return f"/recipes/images/{image_id}.jpg?t={token}"


def read_token(image_id: str, token: str) -> dict:
    """Verify the signature and that the token belongs to this image_id."""
    if not _IMAGE_ID.match(image_id):
        raise InvalidImageToken("Malformed image id.")
    try:
        body_part, sig = token.split(".", 1)
        body = _unb64(body_part)
    except (ValueError, TypeError) as exc:
        raise InvalidImageToken("Malformed image token.") from exc
    if not hmac.compare_digest(_sign(body), sig):
        raise InvalidImageToken("Image token signature does not match.")
    try:
        data = json.loads(body)
    except ValueError as exc:
        raise InvalidImageToken("Malformed image token.") from exc
    if data.get("i") != image_id:
        raise InvalidImageToken("Image token is for a different image.")
    return data


def build_prompt(data: dict) -> str:
    method = {
        "fry": "pan-fried until crisp",
        "grill": "grilled with light char marks",
        "steam": "steamed",
        "curry": "in a rich curry gravy",
        "soup": "in a clear, fragrant broth",
        "bake": "oven-baked",
    }.get(str(data.get("m", "")).lower(), "")
    fish = data.get("f", "fish")
    fish_en = data.get("e") or ""
    fish_desc = f"{fish} ({fish_en})" if fish_en else fish
    return (
        f"Appetising, realistic food photograph of {data.get('t', 'a Malaysian fish dish')}: "
        f"{data.get('d', '')} Made with {fish_desc}{', ' + method if method else ''}. "
        "Malaysian home-style cooking, plated on a ceramic dish on a light marble "
        "kitchen table with fresh herbs, sliced chilli and lime. Soft natural "
        "daylight, 45-degree angle, shallow depth of field, vibrant but natural "
        "colours. No text, no logos, no people, no hands."
    )


def _cache_dir() -> pathlib.Path:
    raw = pathlib.Path(get_settings().recipe_image_cache_dir)
    path = raw if raw.is_absolute() else BACKEND_DIR / raw
    path.mkdir(parents=True, exist_ok=True)
    return path


def cached(image_id: str) -> bytes | None:
    path = _cache_dir() / f"{image_id}.jpg"
    if path.is_file() and path.stat().st_size > 0:
        return path.read_bytes()
    return None


async def _generate_and_store(image_id: str, data: dict) -> bytes:
    image = await openai_client.generate_image(build_prompt(data))
    path = _cache_dir() / f"{image_id}.jpg"
    tmp = path.with_suffix(".tmp")
    tmp.write_bytes(image)
    tmp.replace(path)
    logger.info("Generated recipe photo %s (%d bytes)", image_id, len(image))
    return image


async def get_or_generate(image_id: str, token: str) -> bytes:
    data = read_token(image_id, token)
    hit = cached(image_id)
    if hit is not None:
        return hit
    if not enabled():
        raise openai_client.OpenAIUnavailable("Recipe photos are disabled on this server.")

    task = _inflight.get(image_id)
    if task is None:
        task = asyncio.ensure_future(_generate_and_store(image_id, data))
        _inflight[image_id] = task
        task.add_done_callback(lambda _: _inflight.pop(image_id, None))
    # shield: a client disconnecting mid-generation must not cancel the job
    # that a second viewer (or the retry) is waiting on.
    return await asyncio.shield(task)
