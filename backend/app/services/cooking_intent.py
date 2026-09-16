"""Epic 4 — natural language cooking intent -> structured intent.

"I want to make fish curry for 4 people" becomes

    CookingIntent(dish="Fish curry", method_code="CURRY", servings=4, ...)

The parser is deterministic and rule-based on purpose. Malaysian shoppers mix
English and Malay ("ikan merah masak asam pedas untuk 4 orang"), and the
vocabulary that matters — cooking methods, fish names, a head-count, a budget —
is small and closed. Rules make every chip the UI shows traceable to a word the
user actually typed. An LLM is used only as a fallback when the rules find
nothing at all (see `app.services.smart_swap`).
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

METHOD_CODES = ("GRILL", "STEAM", "FRY", "CURRY", "SOUP", "BAKE")

METHOD_LABELS: dict[str, str] = {
    "GRILL": "Grilled fish",
    "STEAM": "Steamed fish",
    "FRY": "Fried fish",
    "CURRY": "Fish curry",
    "SOUP": "Fish soup",
    "BAKE": "Baked fish",
}

# Specific dishes first: they carry their own display label. First match wins.
DISH_PATTERNS: list[tuple[str, str, str]] = [
    (r"asam\s*pedas", "CURRY", "Asam pedas"),
    (r"masak\s*lemak", "CURRY", "Masak lemak"),
    (r"gulai", "CURRY", "Gulai ikan"),
    (r"kari|curry", "CURRY", "Fish curry"),
    (r"ikan\s*bakar|bbq|barbecue|panggang|grill(?:ed|ing)?", "GRILL", "Grilled fish"),
    (r"tom\s*yam|tomyam", "SOUP", "Tom yam"),
    (r"sup|soup|masak\s*air|broth", "SOUP", "Fish soup"),
    (r"stim|kukus|steam(?:ed|ing)?", "STEAM", "Steamed fish"),
    (r"sumbat", "FRY", "Ikan sumbat"),
    (r"goreng|fr(?:y|ied|ying)|crispy|deep[\s-]?fry|pan[\s-]?fry", "FRY", "Fried fish"),
    (r"oven|bak(?:e|ed|ing)|roast(?:ed)?", "BAKE", "Baked fish"),
]

NUMBER_WORDS: dict[str, int] = {
    "one": 1, "satu": 1, "seorang": 1,
    "two": 2, "dua": 2, "couple": 2,
    "three": 3, "tiga": 3,
    "four": 4, "empat": 4,
    "five": 5, "lima": 5,
    "six": 6, "enam": 6,
    "seven": 7, "tujuh": 7,
    "eight": 8, "lapan": 8,
    "nine": 9, "sembilan": 9,
    "ten": 10, "sepuluh": 10,
    "twelve": 12, "dozen": 12,
}

_PEOPLE = r"(?:people|persons?|pax|orang|guests?|servings?|adults?|ppl)"
_NUM = r"(\d{1,2}|" + "|".join(NUMBER_WORDS) + r")"

SERVING_PATTERNS = [
    re.compile(rf"\b{_NUM}\s*{_PEOPLE}\b"),
    re.compile(rf"\b(?:for|untuk|serves?|feed(?:s|ing)?)\s+{_NUM}\b"),
]

BUDGET_PATTERN = re.compile(
    r"(?:under|below|max(?:imum)?|budget|bawah|kurang\s*dari|<)\s*(?:of\s*)?rm\s*(\d+(?:\.\d+)?)"
    r"|rm\s*(\d+(?:\.\d+)?)\s*(?:/\s*kg|per\s*kg|sekilo)?\s*(?:max|or\s*less|and\s*below)"
)
AFFORDABLE_PATTERN = re.compile(r"\b(cheap(?:er)?|affordable|budget|murah|jimat|save\s*money)\b")
FAMILY_PATTERN = re.compile(r"\b(family|keluarga)\b")
KIDS_PATTERN = re.compile(r"\b(kids?|children|anak)\b")


@dataclass
class CookingIntent:
    """Structured intent. Every field is optional except the raw text."""

    raw_query: str = ""
    dish: str | None = None
    method_code: str | None = None
    servings: int | None = None
    fish_code: str | None = None
    max_price_rm_per_kg: float | None = None
    prefer_affordable: bool = False
    kid_friendly: bool = False
    matched_terms: list[str] = field(default_factory=list)

    @property
    def is_empty(self) -> bool:
        return not (self.method_code or self.fish_code or self.servings)


def _normalise(text: str) -> str:
    return re.sub(r"\s+", " ", text.lower()).strip()


def _to_int(token: str) -> int | None:
    if token.isdigit():
        return int(token)
    return NUMBER_WORDS.get(token)


def match_fish(text: str, names_by_code: dict[str, list[str]]) -> tuple[str | None, str | None]:
    """Longest catalogue name found in the text wins.

    Longest-first stops "bawal" (a loose spelling alias) beating "bawal putih".
    """
    q = f" {_normalise(text)} "
    candidates: list[tuple[int, str, str]] = []
    for code, names in names_by_code.items():
        for name in names:
            n = _normalise(name)
            if len(n) < 4:
                continue
            if re.search(rf"(?<![a-z]){re.escape(n)}(?![a-z])", q):
                candidates.append((len(n), code, name))
    if not candidates:
        return None, None
    candidates.sort(key=lambda row: (-row[0], row[1]))
    _, code, name = candidates[0]
    return code, name


def parse_intent(
    query: str,
    names_by_code: dict[str, list[str]] | None = None,
) -> CookingIntent:
    """Rule-based parse of a free-text cooking request."""
    text = _normalise(query or "")
    intent = CookingIntent(raw_query=(query or "").strip())
    if not text:
        return intent

    for pattern, code, label in DISH_PATTERNS:
        m = re.search(rf"(?<![a-z])(?:{pattern})(?![a-z])", text)
        if m:
            intent.method_code = code
            intent.dish = label
            intent.matched_terms.append(m.group(0))
            break

    for serving_pattern in SERVING_PATTERNS:
        m = serving_pattern.search(text)
        if m:
            value = _to_int(m.group(1))
            if value and 1 <= value <= 30:
                intent.servings = value
                intent.matched_terms.append(m.group(0))
                break
    if intent.servings is None and FAMILY_PATTERN.search(text):
        intent.servings = 4
        intent.matched_terms.append("family")

    m = BUDGET_PATTERN.search(text)
    if m:
        intent.max_price_rm_per_kg = float(m.group(1) or m.group(2))
        intent.prefer_affordable = True
        intent.matched_terms.append(m.group(0))
    if AFFORDABLE_PATTERN.search(text):
        intent.prefer_affordable = True

    if KIDS_PATTERN.search(text):
        intent.kid_friendly = True

    if names_by_code:
        code, name = match_fish(text, names_by_code)
        if code:
            intent.fish_code = code
            intent.matched_terms.append(name or code)

    return intent


def default_dish(method_code: str | None) -> str | None:
    return METHOD_LABELS.get((method_code or "").upper())
