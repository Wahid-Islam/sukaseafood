"""Epic 4 — Cooking Intent, Smart Swap and Recipe generation.

Parser and ranking tests are pure. API tests run against the seeded database
(see conftest.py); OpenAI is never called — the HTTP transport is mocked.
"""

from __future__ import annotations

import json

import httpx
import pytest

from app.services import cooking_intent, openai_client, read_cache
from app.services.smart_swap import FishFacts, qualifies, rank_alternatives

NAMES = {
    "SF003": ["Ikan Merah", "Red Snapper"],
    "SF006": ["Bawal Putih", "Chinese Silver Pomfret"],
    "SF002": ["Bawal Hitam", "Bawal"],
}


# --- intent parser ------------------------------------------------------------


@pytest.mark.parametrize(
    ("query", "method", "servings", "fish"),
    [
        ("I want to make fish curry for 4 people", "CURRY", 4, None),
        ("ikan merah masak asam pedas untuk empat orang", "CURRY", 4, "SF003"),
        ("steamed bawal putih for two", "STEAM", 2, "SF006"),
        ("ikan bakar, 6 pax", "GRILL", 6, None),
        ("tom yam for my family", "SOUP", 4, None),
        ("supper ideas", None, None, None),
    ],
)
def test_parse_intent(query, method, servings, fish):
    intent = cooking_intent.parse_intent(query, NAMES)
    assert intent.method_code == method
    assert intent.servings == servings
    assert intent.fish_code == fish


def test_parse_budget_and_affordable():
    intent = cooking_intent.parse_intent("cheap fried fish under RM15")
    assert intent.method_code == "FRY"
    assert intent.max_price_rm_per_kg == 15.0
    assert intent.prefer_affordable is True


def test_longest_fish_name_wins():
    code, _ = cooking_intent.match_fish("bawal hitam goreng", NAMES)
    assert code == "SF002"


# --- ranking ------------------------------------------------------------------


def _fish(code, classification, curry, price=None, family=None):
    return FishFacts(
        code=code,
        name=code,
        display_name_en=code,
        scientific_name=code,
        fish_type="Marine fish",
        family=family,
        classification=classification,
        image_url=None,
        cooking={"CURRY": (curry, "note"), "FRY": (4, "note")},
        price_rm_per_kg=price,
    )


def test_undetermined_is_never_better():
    current = _fish("CUR", "UNDETERMINED", 4)
    assert not qualifies(_fish("A", "REDUCE", 5), current)
    assert qualifies(_fish("B", "GOOD CHOICE", 5), current)


def test_swap_must_be_strictly_better_and_suit_the_method():
    current = _fish("CUR", "REDUCE", 4, price=28)
    pool = [
        current,
        _fish("SAME", "REDUCE", 5, price=10),        # not better rated
        _fish("WEAK", "GOOD CHOICE", 2, price=10),   # unsuitable for curry
        _fish("OK", "GOOD CHOICE", 3, price=30),
        _fish("BEST", "GOOD CHOICE", 5, price=12),
    ]
    ranked, weights = rank_alternatives(current=current, pool=pool, method_code="CURRY")
    codes = [r.fish.code for r in ranked]
    assert codes == ["BEST", "OK"]
    assert abs(sum(weights.values()) - 1) < 1e-9
    top = ranked[0]
    assert any("cheaper" in reason for reason in top.reasons)
    assert any("5/5 for curry" in reason for reason in top.reasons)


def test_budget_filters_priced_alternatives():
    current = _fish("CUR", "AVOID", 4)
    pool = [_fish("PRICEY", "GOOD CHOICE", 5, price=40), _fish("CHEAP", "REDUCE", 4, price=9)]
    ranked, _ = rank_alternatives(
        current=current, pool=pool, method_code="CURRY", max_price_rm_per_kg=20
    )
    assert [r.fish.code for r in ranked] == ["CHEAP"]


# --- API ----------------------------------------------------------------------


def test_smart_swap_needs_intent(client):
    r = client.post("/api/v1/smart-swap", json={"query": "hello"})
    assert r.status_code == 200
    assert r.json()["status"] == "NEEDS_INTENT"


def test_smart_swap_from_sentence(client):
    r = client.post(
        "/api/v1/smart-swap",
        json={"query": "I want to make fish curry for 4 people", "fish_id": "SF003"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["intent"]["cooking_method"] == "curry"
    assert body["intent"]["servings"] == 4
    assert {c["key"] for c in body["intent"]["chips"]} >= {"dish", "servings"}
    assert body["current"]["fish_id"] == "SF003"
    assert body["status"] in {"SWAP_FOUND", "NO_BETTER_OPTION"}
    if body["status"] == "SWAP_FOUND":
        rec = body["recommended"]
        rank = {"GOOD CHOICE": 0, "REDUCE": 1, "AVOID": 2}
        assert rank[rec["classification"]] < rank[body["current"]["classification"]]
        assert rec["cooking_score"] >= 3
        assert rec["reasons"]


def test_smart_swap_unknown_fish_404(client):
    r = client.post("/api/v1/smart-swap", json={"query": "curry", "fish_id": "SF999"})
    assert r.status_code == 404


def test_recipes_unavailable_without_key(client, monkeypatch):
    from app.config import get_settings

    monkeypatch.setattr(get_settings(), "openai_api_key", "")
    r = client.post("/api/v1/recipes/generate", json={"fish_id": "SF007"})
    assert r.status_code == 503
    assert r.json()["detail"]["error"]["code"] == "RECIPE_UNAVAILABLE"


def test_recipes_generate_with_mocked_openai(client, monkeypatch):
    from app.config import get_settings

    monkeypatch.setattr(get_settings(), "openai_api_key", "sk-test")
    seen: dict = {}
    recipe = {
        "title": "Cencaru Fish Curry",
        "description": "A flavourful curry.",
        "time_minutes": 30,
        "difficulty": "beginner",
        "servings": 4,
        "tags": ["Curry", "Malaysian", "Family friendly"],
        "ingredients": [
            {"name": "Cencaru (cleaned)", "quantity": "2 pieces", "emoji": "🐟"},
            {"name": "Onion", "quantity": "1 large", "emoji": "🧅"},
            {"name": "Coconut milk", "quantity": "200 ml", "emoji": "🥥"},
        ],
        "steps": [
            {"step": 1, "instruction": "Blend the aromatics.", "minutes": 5},
            {"step": 2, "instruction": "Simmer the fish in the gravy.", "minutes": 15},
        ],
        "tips": ["Do not stir too hard."],
    }

    def handler(request: httpx.Request) -> httpx.Response:
        seen["auth"] = request.headers["Authorization"]
        seen["body"] = json.loads(request.content)
        content = json.dumps({"recipes": [recipe]})
        return httpx.Response(200, json={"choices": [{"message": {"content": content}}]})

    openai_client.set_transport_for_tests(httpx.MockTransport(handler))
    read_cache.clear()
    try:
        r = client.post(
            "/api/v1/recipes/generate",
            json={"fish_id": "SF007", "cooking_method": "curry", "servings": 4},
        )
    finally:
        openai_client.set_transport_for_tests(None)

    assert r.status_code == 200, r.text
    body = r.json()
    assert body["recipes"][0]["title"] == "Cencaru Fish Curry"
    assert body["recipes"][0]["difficulty"] == "Beginner"
    assert body["recipes"][0]["servings"] == 4
    assert seen["auth"] == "Bearer sk-test"
    assert seen["body"]["response_format"] == {"type": "json_object"}
    assert "Cencaru" in seen["body"]["messages"][1]["content"]
    assert "sk-test" not in r.text


# --- recipe photos ------------------------------------------------------------


_RECIPE = {
    "title": "Crispy Fried Cencaru",
    "description": "A classic and flavourful Malaysian favourite.",
    "time_minutes": 30,
    "difficulty": "Beginner",
    "servings": 4,
    "tags": ["Fried", "Malaysian"],
    "ingredients": [
        {"name": "Cencaru", "quantity": "4 pieces", "emoji": "🐟"},
        {"name": "Turmeric", "quantity": "1 tsp", "emoji": "🟡"},
        {"name": "Salt", "quantity": "1 tsp", "emoji": "🧂"},
    ],
    "steps": [
        {"step": 1, "instruction": "Rub the fish with turmeric and salt.", "minutes": 5},
        {"step": 2, "instruction": "Shallow-fry until golden on both sides.", "minutes": 12},
    ],
}


def test_image_token_round_trip_and_tamper():
    from app.services import recipe_images

    path = recipe_images.image_path(
        fish_id="SF007",
        fish_name="Cencaru",
        fish_name_en="Hardtail Scad",
        title="Crispy Fried Cencaru",
        description="Crisp and golden.",
        cooking_method="fry",
    )
    image_id = path.split("/recipes/images/")[1].split(".jpg")[0]
    token = path.split("?t=")[1]
    data = recipe_images.read_token(image_id, token)
    assert data["t"] == "Crispy Fried Cencaru"
    assert "Cencaru" in recipe_images.build_prompt(data)

    body, sig = token.split(".")
    with pytest.raises(recipe_images.InvalidImageToken):
        recipe_images.read_token(image_id, body + "x." + sig)
    with pytest.raises(recipe_images.InvalidImageToken):
        recipe_images.read_token("0" * 20, token)


def test_recipes_carry_image_urls_and_photo_is_generated_once(client, monkeypatch, tmp_path):
    import base64

    from app.config import get_settings

    settings = get_settings()
    monkeypatch.setattr(settings, "openai_api_key", "sk-test")
    monkeypatch.setattr(settings, "recipe_images_enabled", True)
    monkeypatch.setattr(settings, "recipe_image_cache_dir", str(tmp_path))

    fake_jpeg = b"\xff\xd8\xff\xe0fake-jpeg-bytes\xff\xd9"
    calls = {"chat": 0, "image": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/chat/completions"):
            calls["chat"] += 1
            content = json.dumps({"recipes": [_RECIPE]})
            return httpx.Response(200, json={"choices": [{"message": {"content": content}}]})
        calls["image"] += 1
        body = json.loads(request.content)
        assert body["model"] == settings.openai_image_model
        assert body["output_format"] == "jpeg"
        assert "Cencaru" in body["prompt"]
        return httpx.Response(200, json={"data": [{"b64_json": base64.b64encode(fake_jpeg).decode()}]})

    openai_client.set_transport_for_tests(httpx.MockTransport(handler))
    read_cache.clear()
    try:
        r = client.post(
            "/api/v1/recipes/generate",
            json={"fish_id": "SF007", "cooking_method": "fry", "servings": 4,
                  "difficulty": "Beginner", "dietary": "Low spice"},
        )
        assert r.status_code == 200, r.text
        recipe = r.json()["recipes"][0]
        assert recipe["image_url"].startswith("/recipes/images/")
        assert calls == {"chat": 1, "image": 0}, "photos are made lazily, not in the POST"

        first = client.get("/api/v1" + recipe["image_url"])
        assert first.status_code == 200
        assert first.headers["content-type"] == "image/jpeg"
        assert first.content == fake_jpeg

        again = client.get("/api/v1" + recipe["image_url"])
        assert again.content == fake_jpeg
        assert calls["image"] == 1, "second request is served from the cache"

        forged = client.get("/api/v1" + recipe["image_url"][:-3] + "abc")
        assert forged.status_code == 403
    finally:
        openai_client.set_transport_for_tests(None)
