"""Epic 4 — recipe generation with OpenAI.

The model is given the facts SukaSeafood already holds about the chosen fish
(names, type, the curated cooking note for the intended method) and asked for
recipes as strict JSON. Every recipe is validated against `RecipeOut` before it
reaches the client; anything malformed is dropped rather than patched up.

What the model is NOT asked to do: rate sustainability, quote prices, or make
nutrition or health claims. Those stay with WWF, PriceCatcher and nobody,
respectively.
"""

from __future__ import annotations

import hashlib
import json
import logging
import re

from pydantic import ValidationError
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import get_settings
from app.models import CookingSuitability, SeafoodItem
from app.schemas import RecipeGenerateOut, RecipeGenerateRequest, RecipeOut
from app.services import cooking_intent, openai_client, read_cache, recipe_images
from app.services import seafood as seafood_service

logger = logging.getLogger(__name__)

CACHE_TTL_SECONDS = 30 * 60


class FishNotFound(LookupError):
    pass


CUISINES = ("Malay", "Chinese", "Indian")

CUISINE_HINTS = {
    "Malay": "Malay home cooking, e.g. asam pedas, masak lemak, ikan bakar, sambal, gulai, goreng kunyit",
    "Chinese": "Malaysian Chinese home cooking, e.g. Teochew/Cantonese steaming, soy-ginger, sweet-sour, black bean, fish head curry, fish soup with tofu",
    "Indian": "Malaysian Indian home cooking, e.g. meen kulambu, fish varuval, fish molee, pepper fry, tamarind fish curry with curry leaves",
}


def cuisines_for(request: RecipeGenerateRequest) -> list[str]:
    """One cuisine per recipe: Malay, Chinese, Indian by default, cycling.

    "Show 3 more" continues the rotation from how many recipes the client
    already has (exclude_titles), so every batch stays mixed.
    """
    base = list(request.cuisines) if request.cuisines else list(CUISINES)
    offset = 0 if request.cuisines else len(request.exclude_titles) % len(base)
    return [base[(offset + i) % len(base)] for i in range(request.count)]


SYSTEM_PROMPT = """You are the recipe writer for SukaSeafood, a Malaysian app that helps \
home cooks choose sustainable seafood. Malaysia's kitchens are Malay, Chinese and Indian, \
and you write authentic home-style recipes from all three, using ingredients easily found \
in a Malaysian wet market or supermarket.

Rules:
- The named fish is the only seafood in the recipe. Refer to it by its Malay name.
- Scale every quantity to the requested number of servings. Allow roughly \
150-200 g of fish per adult serving, or whole fish/pieces where that is how it is sold.
- Cooking times must be realistic and the fish must be cooked through.
- Do not mention sustainability ratings, prices, calories, nutrition or health claims.
- Quantities use metric or everyday Malaysian units (g, ml, tbsp, tsp, pieces, cloves, stalks).
- Each ingredient gets one fitting emoji.
- Each recipe is assigned a cuisine (Malay, Chinese or Indian). Write a dish that \
home cooks of that community in Malaysia would recognise, with that cuisine's own \
aromatics, sauces and techniques, while keeping the requested cooking method. If the \
requested dish belongs to one cuisine (e.g. asam pedas is Malay), use it for that \
cuisine and give the closest same-method dish for the others.
- Titles may use the dish's usual local name (Malay, Chinese or Tamil/English) and \
must include the fish's Malay name.
- Halal-friendly for every cuisine: no pork, lard, alcohol or rice wine (use \
alternatives such as extra ginger, stock or a splash of vinegar).
- The description is one short, appetising sentence (max 20 words) for a recipe card.

Reply with a single JSON object exactly in this shape:
{"recipes": [{
  "title": "string (short, includes the fish's Malay name)",
  "description": "one or two sentences",
  "time_minutes": integer,
  "difficulty": "Beginner" | "Intermediate" | "Advanced",
  "servings": integer,
  "cuisine": "Malay" | "Chinese" | "Indian",
  "tags": ["3 short tags, e.g. Curry, Family friendly, Quick"],
  "ingredients": [{"name": "string", "quantity": "string", "emoji": "string", "note": "optional string"}],
  "steps": [{"step": 1, "instruction": "string", "minutes": integer or null}],
  "tips": ["up to 2 short tips"]
}]}"""


async def _load_fish(session: AsyncSession, fish_id: str) -> SeafoodItem | None:
    identifier = fish_id.strip().upper()
    stmt = (
        select(SeafoodItem)
        .where(func.upper(SeafoodItem.code) == identifier)
        .options(
            selectinload(SeafoodItem.aliases),
            selectinload(SeafoodItem.cooking_suitability).selectinload(
                CookingSuitability.method
            ),
        )
    )
    item = await session.scalar(stmt)
    if item is None:
        # UUIDs from /identify are accepted too.
        item = await seafood_service.get_seafood_by_id(session, fish_id)
    return item


def _user_prompt(item: SeafoodItem, request: RecipeGenerateRequest, method: str | None) -> str:
    short = item.canonical_name_ms.split(" / ")[0]
    lines = [
        f"Fish: {short} ({item.display_name_en}, {item.scientific_name}).",
        f"Fish type: {item.fish_type or item.family or 'fish'}.",
    ]
    dish = (request.dish or "").strip() or cooking_intent.default_dish(method)
    if dish:
        lines.append(f"The cook wants to make: {dish}.")
    if method:
        lines.append(f"Cooking method: {method.lower()}.")
        for row in item.cooking_suitability or []:
            if row.method is not None and row.method.code.upper() == method:
                lines.append(
                    f"SukaSeafood cooking note for this fish ({row.suitability_score}/5): "
                    f"{row.reason_en}"
                )
    lines.append(f"Servings: {request.servings}.")
    if request.kid_friendly:
        lines.append("Make it kid friendly: mild chilli, bones easy to remove.")
    if request.difficulty:
        lines.append(f"Every recipe must be {request.difficulty} difficulty.")
    if request.dietary and request.dietary.strip():
        lines.append(f"Dietary preference to respect: {request.dietary.strip()[:60]}.")
    if request.exclude_titles:
        lines.append(
            "Do not repeat these recipes; give clearly different dishes or styles: "
            + "; ".join(t.strip()[:80] for t in request.exclude_titles if t.strip())
            + "."
        )
    cuisines = cuisines_for(request)
    lines.append(
        f"Write {request.count} recipe{'s' if request.count > 1 else ''}, in this "
        f"order and cuisine: "
        + "; ".join(
            f"{i + 1}. {c} ({CUISINE_HINTS.get(c, c)})" for i, c in enumerate(cuisines)
        )
        + "."
    )
    return "\n".join(lines)


def _coerce(
    raw: dict,
    *,
    item: SeafoodItem,
    method: str | None,
    servings: int,
    expected_cuisine: str | None = None,
) -> RecipeOut | None:
    """Validate one model recipe; return None if it cannot be trusted."""
    if not isinstance(raw, dict):
        return None
    try:
        steps = raw.get("steps") or []
        normalised_steps = []
        for index, step in enumerate(steps, start=1):
            if isinstance(step, str):
                step = {"instruction": step}
            if not isinstance(step, dict) or not str(step.get("instruction", "")).strip():
                continue
            minutes = step.get("minutes")
            normalised_steps.append(
                {
                    "step": index,
                    "instruction": str(step["instruction"]).strip(),
                    "minutes": int(minutes) if isinstance(minutes, (int, float)) and minutes > 0 else None,
                }
            )
        ingredients = [
            {
                "name": str(i.get("name", "")).strip(),
                "quantity": str(i.get("quantity", "")).strip() or "to taste",
                "emoji": str(i.get("emoji", "")).strip()[:4],
                "note": str(i.get("note", "") or "").strip(),
            }
            for i in (raw.get("ingredients") or [])
            if isinstance(i, dict) and str(i.get("name", "")).strip()
        ]
        difficulty = str(raw.get("difficulty", "Beginner")).strip().title()
        if difficulty not in {"Beginner", "Intermediate", "Advanced"}:
            difficulty = "Intermediate"
        title = str(raw.get("title", "")).strip()
        digest = hashlib.sha1(
            f"{item.code}|{title}|{servings}".encode("utf-8")
        ).hexdigest()[:12]
        recipe = RecipeOut(
            recipe_id=f"{item.code.lower()}-{digest}",
            title=title,
            description=str(raw.get("description", "")).strip(),
            fish_id=item.code,
            fish_name=item.canonical_name_ms.split(" / ")[0],
            cooking_method=method.lower() if method else None,
            time_minutes=max(5, min(240, int(raw.get("time_minutes") or 30))),
            difficulty=difficulty,
            servings=servings,
            cuisine=_cuisine(raw.get("cuisine"), expected_cuisine),
            tags=[str(t).strip() for t in (raw.get("tags") or []) if str(t).strip()][:4],
            ingredients=ingredients,
            steps=normalised_steps,
            tips=[str(t).strip() for t in (raw.get("tips") or []) if str(t).strip()][:3],
        )
    except (ValidationError, TypeError, ValueError) as exc:
        logger.info("Dropped malformed recipe from model: %s", exc)
        return None
    if not recipe.title or len(recipe.ingredients) < 3 or len(recipe.steps) < 2:
        return None
    return recipe


def _cuisine(value: object, expected: str | None) -> str | None:
    text = str(value or "").strip().title()
    return text if text in CUISINES else expected


def _cache_key(item: SeafoodItem, request: RecipeGenerateRequest, method: str | None) -> str:
    payload = {
        "fish": item.code,
        "method": method,
        "dish": (request.dish or "").strip().lower(),
        "servings": request.servings,
        "count": request.count,
        "exclude": sorted(t.strip().lower() for t in request.exclude_titles),
        "kids": request.kid_friendly,
        "difficulty": request.difficulty,
        "dietary": (request.dietary or "").strip().lower(),
        "images": request.include_images and recipe_images.enabled(),
        "cuisines": cuisines_for(request),
    }
    return "recipes:" + hashlib.sha1(json.dumps(payload, sort_keys=True).encode()).hexdigest()


async def generate_recipes(
    session: AsyncSession, request: RecipeGenerateRequest
) -> RecipeGenerateOut:
    settings = get_settings()
    item = await _load_fish(session, request.fish_id)
    if item is None:
        raise FishNotFound(f"Seafood {request.fish_id!r} was not found.")

    method: str | None = None
    if request.cooking_method:
        raw = request.cooking_method.strip()
        code = seafood_service.COOKING_ALIASES.get(raw.lower(), raw.upper())
        method = code if code in cooking_intent.METHOD_CODES else None

    key = _cache_key(item, request, method)
    cached = read_cache.get(key, ttl_seconds=CACHE_TTL_SECONDS)
    if isinstance(cached, RecipeGenerateOut):
        return cached

    data = await openai_client.chat_json(
        system=SYSTEM_PROMPT,
        user=_user_prompt(item, request, method),
        max_completion_tokens=1400 * request.count + 400,
    )
    raw_recipes = data.get("recipes")
    if isinstance(data.get("title"), str):  # a single bare recipe object
        raw_recipes = [data]
    excluded = {re.sub(r"\W+", "", t.lower()) for t in request.exclude_titles}
    recipes: list[RecipeOut] = []
    expected = cuisines_for(request)
    for index, raw in enumerate(raw_recipes or []):
        recipe = _coerce(
            raw,
            item=item,
            method=method,
            servings=request.servings,
            expected_cuisine=expected[index] if index < len(expected) else None,
        )
        if recipe is None or re.sub(r"\W+", "", recipe.title.lower()) in excluded:
            continue
        if request.include_images and recipe_images.enabled():
            recipe.image_url = recipe_images.image_path(
                fish_id=item.code,
                fish_name=recipe.fish_name,
                fish_name_en=item.display_name_en,
                title=recipe.title,
                description=recipe.description,
                cooking_method=recipe.cooking_method,
                cuisine=recipe.cuisine,
            )
        recipes.append(recipe)
    if not recipes:
        raise openai_client.OpenAIError("The model did not return a usable recipe.")

    payload = RecipeGenerateOut(
        fish_id=item.code,
        recipes=recipes[: request.count],
        generated_by=f"openai:{settings.openai_model}",
    )
    read_cache.put(key, payload)
    return payload
