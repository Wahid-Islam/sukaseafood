"""Minimal OpenAI Chat Completions client (JSON mode) over httpx.

No SDK dependency: httpx is already in requirements, and the only call the
product makes is "send a prompt, get a JSON object back". Keeping it this small
also keeps key handling obvious in review — the key is read from settings and
sent in one header, never logged and never returned to a client.
"""

from __future__ import annotations

import json
import logging
from typing import Any

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)


class OpenAIUnavailable(RuntimeError):
    """No API key is configured on this server."""


class OpenAIError(RuntimeError):
    """OpenAI answered with an error, timed out, or returned unusable JSON."""


# Tests swap this for an httpx.MockTransport.
_transport: httpx.AsyncBaseTransport | None = None


def set_transport_for_tests(transport: httpx.AsyncBaseTransport | None) -> None:
    global _transport
    _transport = transport


async def chat_json(
    *,
    system: str,
    user: str,
    max_completion_tokens: int = 1800,
) -> dict[str, Any]:
    """Run one chat completion constrained to a JSON object and parse it."""
    settings = get_settings()
    if not settings.openai_enabled:
        raise OpenAIUnavailable(
            "Recipe generation is not configured on this server (OPENAI_API_KEY is empty)."
        )

    payload = {
        "model": settings.openai_model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "response_format": {"type": "json_object"},
        # Accepted by every current chat model, including reasoning models
        # that reject the older max_tokens.
        "max_completion_tokens": max_completion_tokens,
    }
    headers = {
        "Authorization": f"Bearer {settings.openai_api_key.strip()}",
        "Content-Type": "application/json",
    }
    url = settings.openai_base_url.rstrip("/") + "/chat/completions"

    try:
        async with httpx.AsyncClient(
            timeout=settings.openai_timeout_seconds, transport=_transport
        ) as client:
            response = await client.post(url, headers=headers, json=payload)
    except httpx.HTTPError as exc:
        raise OpenAIError(f"Could not reach OpenAI ({type(exc).__name__}).") from exc

    if response.status_code != 200:
        message = ""
        try:
            message = response.json().get("error", {}).get("message", "")
        except ValueError:
            pass
        logger.warning("OpenAI returned %s: %s", response.status_code, message)
        raise OpenAIError(f"OpenAI request failed ({response.status_code}). {message}".strip())

    try:
        content = response.json()["choices"][0]["message"]["content"]
        parsed = json.loads(content)
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        raise OpenAIError("OpenAI returned a response that was not valid JSON.") from exc

    if not isinstance(parsed, dict):
        raise OpenAIError("OpenAI returned JSON that was not an object.")
    return parsed
