"""Epic 4 — Smart Swap: rank better seafood for what the user is cooking.

Pipeline:  natural language -> structured intent -> explainable ranking.

Ranking is deterministic. Every alternative gets four 0-1 component scores

    sustainability  WWF Save Our Seafood rating on file
    cooking         curated cooking_suitability score for the intended method
    price           latest observed PriceCatcher median vs. the user's choice
    attributes      food-use similarity to the user's choice + versatility

combined with published weights, plus the plain-language reasons behind them,
so a card can say *why* one species beat another rather than just that it did.

Two product rules are enforced here and never relaxed by weighting:

  * A swap must be strictly better rated than the user's choice.
    UNDETERMINED is never "better"; against an UNDETERMINED choice only a
    documented GOOD CHOICE qualifies.
  * A species with no curated score for the intended method is not suggested
    for it — suitability is never invented.
"""

from __future__ import annotations

import logging
import statistics
import uuid
from dataclasses import dataclass, field
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models import PricePeriodSummary, PriceTrendPoint, SeafoodItem
from app.models.enums import PeriodType, PriceQuality
from app.schemas import (
    CookingIntentOut,
    IntentChipOut,
    ScoreBreakdownOut,
    SmartSwapOut,
    SmartSwapRequest,
    SwapFishOut,
)
from app.services import cooking_intent, openai_client, read_cache
from app.services import seafood as seafood_service

logger = logging.getLogger(__name__)

SUSTAINABILITY_SCORE = {"GOOD CHOICE": 1.0, "REDUCE": 0.45, "AVOID": 0.0}
SUSTAINABILITY_RANK = {"GOOD CHOICE": 0, "REDUCE": 1, "AVOID": 2}
UNDETERMINED_RANK = 9
UNDETERMINED_SCORE = 0.2
WWF_COLOUR = {"GOOD CHOICE": "Green", "REDUCE": "Yellow", "AVOID": "Red"}
MIN_COOKING_SCORE = 3

DEFAULT_WEIGHTS = {"sustainability": 0.40, "cooking": 0.35, "price": 0.15, "attributes": 0.10}
AFFORDABLE_WEIGHTS = {"sustainability": 0.35, "cooking": 0.30, "price": 0.25, "attributes": 0.10}

METHOD_WORD = {
    "GRILL": "grilling",
    "STEAM": "steaming",
    "FRY": "frying",
    "CURRY": "curry",
    "SOUP": "soup",
    "BAKE": "baking",
}


# --- pure domain -------------------------------------------------------------


@dataclass
class FishFacts:
    """Everything the ranking needs about one species, detached from the ORM."""

    code: str
    name: str
    display_name_en: str
    scientific_name: str
    fish_type: str
    family: str | None
    classification: str
    image_url: str | None
    cooking: dict[str, tuple[int, str]] = field(default_factory=dict)
    price_rm_per_kg: float | None = None

    @property
    def rank(self) -> int:
        return SUSTAINABILITY_RANK.get(self.classification, UNDETERMINED_RANK)

    @property
    def versatility(self) -> float:
        """Share of methods this fish is genuinely good at (score 4-5)."""
        return min(1.0, sum(1 for score, _ in self.cooking.values() if score >= 4) / 5)


@dataclass
class Ranked:
    fish: FishFacts
    score: float
    breakdown: dict[str, float]
    reasons: list[str]
    caveats: list[str]


def _clamp(value: float) -> float:
    return max(0.0, min(1.0, value))


def _label(classification: str) -> str:
    return "Unrated" if classification not in SUSTAINABILITY_RANK else classification.title()


def qualifies(candidate: FishFacts, current: FishFacts | None) -> bool:
    """The hard sustainability gate — never overridden by weighting."""
    if current is None:
        return candidate.rank <= SUSTAINABILITY_RANK["REDUCE"]
    if current.rank == UNDETERMINED_RANK:
        return candidate.rank == SUSTAINABILITY_RANK["GOOD CHOICE"]
    return candidate.rank < current.rank


def rank_alternatives(
    *,
    current: FishFacts | None,
    pool: list[FishFacts],
    method_code: str | None,
    max_price_rm_per_kg: float | None = None,
    prefer_affordable: bool = False,
) -> tuple[list[Ranked], dict[str, float]]:
    """Filter by the hard rules, then score and sort. Pure: no IO."""
    weights = AFFORDABLE_WEIGHTS if prefer_affordable else DEFAULT_WEIGHTS
    method = (method_code or "").upper() or None
    method_word = METHOD_WORD.get(method or "", "this dish")

    eligible: list[FishFacts] = []
    for fish in pool:
        if current is not None and fish.code == current.code:
            continue
        if not qualifies(fish, current):
            continue
        if method and fish.cooking.get(method, (0, ""))[0] < MIN_COOKING_SCORE:
            continue
        if (
            max_price_rm_per_kg is not None
            and fish.price_rm_per_kg is not None
            and fish.price_rm_per_kg > max_price_rm_per_kg
        ):
            continue
        eligible.append(fish)

    priced = [f.price_rm_per_kg for f in eligible if f.price_rm_per_kg]
    if current is not None and current.price_rm_per_kg:
        reference_price: float | None = current.price_rm_per_kg
    elif priced:
        reference_price = statistics.median(priced)
    else:
        reference_price = None

    ranked: list[Ranked] = []
    for fish in eligible:
        reasons: list[str] = []
        caveats: list[str] = []

        # Sustainability ------------------------------------------------------
        sustainability = SUSTAINABILITY_SCORE.get(fish.classification, UNDETERMINED_SCORE)
        if current is not None:
            reasons.append(
                f"WWF {_label(fish.classification)} — better rated than "
                f"{current.name} ({_label(current.classification)})."
            )
        else:
            reasons.append(f"WWF {_label(fish.classification)} rating on file.")
        if fish.classification == "REDUCE":
            caveats.append("WWF suggests eating this less often.")

        # Cooking suitability -------------------------------------------------
        if method:
            stars, why = fish.cooking[method]
            cooking = stars / 5
            reasons.append(f"Rated {stars}/5 for {method_word}: {why}")
            if stars == MIN_COOKING_SCORE:
                caveats.append(f"Workable for {method_word}, but not its best use.")
        else:
            cooking = fish.versatility
            best = sorted(fish.cooking.items(), key=lambda kv: -kv[1][0])[:2]
            if best:
                reasons.append(
                    "Best for "
                    + " and ".join(METHOD_WORD.get(k, k.lower()) for k, _ in best)
                    + "."
                )

        # Price ---------------------------------------------------------------
        if fish.price_rm_per_kg and reference_price:
            diff = (reference_price - fish.price_rm_per_kg) / reference_price
            price = _clamp(0.5 + diff)
            if current is not None and current.price_rm_per_kg:
                if diff >= 0.05:
                    reasons.append(
                        f"About {round(diff * 100)}% cheaper: RM {fish.price_rm_per_kg:.2f}/kg "
                        f"vs RM {current.price_rm_per_kg:.2f}/kg."
                    )
                elif diff <= -0.05:
                    caveats.append(
                        f"Costs more: RM {fish.price_rm_per_kg:.2f}/kg "
                        f"vs RM {current.price_rm_per_kg:.2f}/kg."
                    )
        else:
            price = 0.5
            caveats.append("No recent observed price on file.")

        # Food-use attributes -------------------------------------------------
        versatility = fish.versatility
        if current is not None:
            similarity = 0.0
            if fish.fish_type and fish.fish_type == current.fish_type:
                similarity += 0.5
            if fish.family and fish.family == current.family:
                similarity += 0.5
                reasons.append(
                    f"Same family as {current.name} ({fish.family}) — similar texture in the pot."
                )
            attributes = 0.6 * similarity + 0.4 * versatility
        else:
            attributes = versatility

        breakdown = {
            "sustainability": round(sustainability, 3),
            "cooking": round(cooking, 3),
            "price": round(price, 3),
            "attributes": round(_clamp(attributes), 3),
        }
        total = sum(weights[k] * v for k, v in breakdown.items())
        ranked.append(Ranked(fish, total, breakdown, reasons, caveats))

    ranked.sort(key=lambda r: (-r.score, r.fish.rank, r.fish.code))
    return ranked, weights


def build_chips(intent: CookingIntentOut) -> list[IntentChipOut]:
    chips: list[IntentChipOut] = []
    if intent.dish:
        chips.append(IntentChipOut(key="dish", label=intent.dish))
    if intent.servings:
        noun = "person" if intent.servings == 1 else "people"
        chips.append(IntentChipOut(key="servings", label=f"{intent.servings} {noun}"))
    if intent.fish_name:
        chips.append(IntentChipOut(key="fish", label=intent.fish_name))
    if intent.max_price_rm_per_kg:
        chips.append(
            IntentChipOut(key="budget", label=f"≤ RM {intent.max_price_rm_per_kg:g}/kg")
        )
    elif intent.prefer_affordable:
        chips.append(IntentChipOut(key="affordable", label="Affordable"))
    if intent.kid_friendly:
        chips.append(IntentChipOut(key="kids", label="Kid friendly"))
    return chips


def to_card(fish: FishFacts, method: str | None, ranked: Ranked | None) -> SwapFishOut:
    """Card payload. `ranked is None` means this is the user's own choice."""
    stars, note = fish.cooking.get(method or "", (None, None))
    if ranked is not None:
        breakdown = ranked.breakdown
        reasons, caveats, score = ranked.reasons, ranked.caveats, ranked.score
    else:
        breakdown = {
            "sustainability": SUSTAINABILITY_SCORE.get(fish.classification, UNDETERMINED_SCORE),
            "cooking": (stars or 0) / 5 if method else fish.versatility,
            "price": 0.5,
            "attributes": 0.0,
        }
        score = sum(DEFAULT_WEIGHTS[k] * v for k, v in breakdown.items())
        reasons = []
        caveats = (
            ["Consider: better-rated options may be available."]
            if fish.classification != "GOOD CHOICE"
            else []
        )
    return SwapFishOut(
        fish_id=fish.code,
        name=fish.name,
        display_name_en=fish.display_name_en,
        scientific_name=fish.scientific_name,
        fish_type=fish.fish_type,
        image_url=fish.image_url,
        classification=fish.classification,
        wwf_colour=WWF_COLOUR.get(fish.classification, "Unrated"),
        is_better_choice=fish.classification == "GOOD CHOICE",
        cooking_method=method.lower() if method else None,
        cooking_score=stars,
        cooking_note=note,
        price_rm_per_kg=round(fish.price_rm_per_kg, 2) if fish.price_rm_per_kg else None,
        price_status="Observed" if fish.price_rm_per_kg else "Insufficient data",
        score=round(_clamp(score) * 100),
        score_breakdown=ScoreBreakdownOut(**breakdown),
        reasons=reasons,
        caveats=caveats,
    )


# --- IO ----------------------------------------------------------------------


def _facts(item: SeafoodItem) -> FishFacts:
    summary = seafood_service.to_summary(item)
    cooking: dict[str, tuple[int, str]] = {}
    for row in item.cooking_suitability or []:
        if row.method is None or not row.suitability_score:
            continue
        cooking[row.method.code.upper()] = (int(row.suitability_score), row.reason_en)
    return FishFacts(
        code=item.code,
        name=summary.primary_common_name.split(" / ")[0],
        display_name_en=item.display_name_en,
        scientific_name=item.scientific_name,
        fish_type=summary.fish_type,
        family=(item.family or "").strip() or None,
        classification=summary.classification or "UNDETERMINED",
        image_url=summary.image_url,
        cooking=cooking,
    )


async def _latest_prices(
    session: AsyncSession, item_ids: list[uuid.UUID]
) -> dict[uuid.UUID, float]:
    """Latest displayable weekly median per species.

    Mirrors `seafood_service.get_price_context` — the number the price screen
    shows — but for the whole pool in two queries instead of two per species.
    """
    if not item_ids:
        return {}
    summaries = await session.scalars(
        select(PricePeriodSummary)
        .where(PricePeriodSummary.seafood_item_id.in_(item_ids))
        .where(PricePeriodSummary.period_type == PeriodType.MONTH)
        .order_by(PricePeriodSummary.seafood_item_id, PricePeriodSummary.period_end.desc())
    )
    latest: dict[uuid.UUID, PricePeriodSummary] = {}
    for row in summaries:
        latest.setdefault(row.seafood_item_id, row)
    displayable = {
        k: v for k, v in latest.items() if v.quality_status == PriceQuality.DISPLAYABLE
    }
    if not displayable:
        return {}

    since = min(v.period_end for v in displayable.values()) - timedelta(days=120)
    points = await session.scalars(
        select(PriceTrendPoint)
        .where(PriceTrendPoint.seafood_item_id.in_(list(displayable)))
        .where(PriceTrendPoint.quality_status == PriceQuality.DISPLAYABLE)
        .where(PriceTrendPoint.week_start >= since)
        .order_by(PriceTrendPoint.week_start.desc())
    )
    prices: dict[uuid.UUID, float] = {}
    for point in points:
        summary = displayable.get(point.seafood_item_id)
        if summary is None or point.seafood_item_id in prices:
            continue
        if point.location_id == summary.location_id and point.weekly_median_price:
            prices[point.seafood_item_id] = float(point.weekly_median_price)
    for item_id, summary in displayable.items():
        if item_id not in prices and summary.median_price is not None:
            prices[item_id] = float(summary.median_price)
    return prices


async def _llm_intent(query: str, catalogue: list[FishFacts]) -> dict | None:
    """Fallback parse for sentences the rules could not read at all."""
    if not get_settings().openai_enabled:
        return None
    fish_lines = "\n".join(f"{f.code}: {f.name} ({f.display_name_en})" for f in catalogue)
    system = (
        "You convert a Malaysian home cook's request into JSON. Reply with a JSON "
        "object with keys: cooking_method (one of GRILL, STEAM, FRY, CURRY, SOUP, "
        "BAKE, or null), dish (short dish name, or null), servings (integer or "
        "null), fish_code (a code from the list, or null), prefer_affordable "
        "(boolean), max_price_rm_per_kg (number or null). Only use information "
        "present in the request; use null when unsure.\n"
        f"Fish list:\n{fish_lines}"
    )
    try:
        return await openai_client.chat_json(
            system=system, user=query, max_completion_tokens=300
        )
    except (openai_client.OpenAIError, openai_client.OpenAIUnavailable) as exc:
        logger.info("LLM intent fallback skipped: %s", exc)
        return None


def _apply_llm(parsed: cooking_intent.CookingIntent, llm: dict, known_codes: set[str]) -> None:
    """Copy only validated values from the LLM answer."""
    method = str(llm.get("cooking_method") or "").upper()
    if method in cooking_intent.METHOD_CODES:
        parsed.method_code = method
        parsed.dish = str(llm.get("dish") or "").strip()[:60] or None
    servings = llm.get("servings")
    if isinstance(servings, int) and 1 <= servings <= 30:
        parsed.servings = servings
    code = str(llm.get("fish_code") or "").upper()
    if code in known_codes:
        parsed.fish_code = code
    parsed.prefer_affordable = parsed.prefer_affordable or llm.get("prefer_affordable") is True
    price = llm.get("max_price_rm_per_kg")
    if isinstance(price, (int, float)) and not isinstance(price, bool) and 0 < price <= 1000:
        parsed.max_price_rm_per_kg = float(price)


async def smart_swap(session: AsyncSession, request: SmartSwapRequest) -> SmartSwapOut:
    settings = get_settings()
    items = await seafood_service.list_seafood(session)
    catalogue = [_facts(item) for item in items]
    by_code = {f.code: f for f in catalogue}

    # 1. Natural language -> structured intent -------------------------------
    names_by_code = {
        item.code: [
            item.canonical_name_ms,
            *item.canonical_name_ms.split(" / "),
            item.display_name_en,
            item.scientific_name,
        ]
        for item in items
    }
    parsed = cooking_intent.parse_intent(request.query or "", names_by_code)
    source = "rules" if (request.query or "").strip() else "structured"

    if (request.query or "").strip() and parsed.is_empty:
        llm = await _llm_intent(request.query or "", catalogue)
        if llm:
            _apply_llm(parsed, llm, set(by_code))
            if not parsed.is_empty:
                source = "llm"

    # Structured fields from the client override the parse.
    if request.cooking_method is not None:
        raw = request.cooking_method.strip()
        code = seafood_service.COOKING_ALIASES.get(raw.lower(), raw.upper())
        parsed.method_code = code if code in cooking_intent.METHOD_CODES else None
        if request.dish is None:
            parsed.dish = cooking_intent.default_dish(parsed.method_code)
    if request.dish is not None:
        parsed.dish = request.dish.strip() or None
    if request.servings is not None:
        parsed.servings = request.servings
    if request.fish_id is not None:
        parsed.fish_code = request.fish_id.strip().upper() or None
    if request.max_price_rm_per_kg is not None:
        parsed.max_price_rm_per_kg = request.max_price_rm_per_kg
    if request.prefer_affordable is not None:
        parsed.prefer_affordable = request.prefer_affordable
    if request.kid_friendly is not None:
        parsed.kid_friendly = request.kid_friendly
    if parsed.method_code and not parsed.dish:
        parsed.dish = cooking_intent.default_dish(parsed.method_code)

    current = by_code.get(parsed.fish_code or "")
    inferred: list[str] = []
    method = parsed.method_code
    if method is None and current is not None and current.cooking:
        method = max(current.cooking.items(), key=lambda kv: kv[1][0])[0]
        inferred.append("cooking_method")

    intent = CookingIntentOut(
        raw_query=parsed.raw_query,
        dish=parsed.dish,
        cooking_method=method.lower() if method else None,
        servings=parsed.servings,
        fish_id=current.code if current else None,
        fish_name=current.name if current else None,
        max_price_rm_per_kg=parsed.max_price_rm_per_kg,
        prefer_affordable=parsed.prefer_affordable,
        kid_friendly=parsed.kid_friendly,
        source=source,
        inferred_fields=inferred,
    )
    intent.chips = build_chips(intent)
    weights = AFFORDABLE_WEIGHTS if parsed.prefer_affordable else DEFAULT_WEIGHTS

    if method is None and current is None:
        return SmartSwapOut(
            intent=intent,
            status="NEEDS_INTENT",
            message="Tell us what you're cooking — for example “fish curry for 4 people”.",
            ranking_weights=weights,
            recipes_available=settings.openai_enabled,
        )

    # 2. Prices for the whole pool (two queries, cached briefly) -------------
    prices = read_cache.get("smart-swap:prices", ttl_seconds=300)
    if not isinstance(prices, dict):
        by_id = await _latest_prices(session, [item.seafood_item_id for item in items])
        prices = {item.code: by_id.get(item.seafood_item_id) for item in items}
        read_cache.put("smart-swap:prices", prices)
    for fish in catalogue:
        fish.price_rm_per_kg = prices.get(fish.code)

    # 3. Explainable ranking --------------------------------------------------
    ranked, weights = rank_alternatives(
        current=current,
        pool=catalogue,
        method_code=method,
        max_price_rm_per_kg=parsed.max_price_rm_per_kg,
        prefer_affordable=parsed.prefer_affordable,
    )
    current_card = to_card(current, method, None) if current else None
    cards = [to_card(r.fish, method, r) for r in ranked[: request.limit + 1]]
    method_word = METHOD_WORD.get(method or "", "your dish")

    if current is not None and current.classification == "GOOD CHOICE":
        stars = current.cooking.get(method or "", (None, ""))[0]
        return SmartSwapOut(
            intent=intent,
            status="ALREADY_GOOD",
            message=(
                f"{current.name} is already a WWF Good Choice"
                + (f" and scores {stars}/5 for {method_word}." if stars else ".")
                + " No swap needed."
            ),
            current=current_card,
            ranking_weights=weights,
            recipes_available=settings.openai_enabled,
        )

    if not cards:
        who = f" instead of {current.name}" if current else ""
        budget = " within your budget" if parsed.max_price_rm_per_kg else ""
        return SmartSwapOut(
            intent=intent,
            status="NO_BETTER_OPTION",
            message=(
                f"No better-rated species on file suits {method_word}{who}{budget}. "
                "We don't invent a swap."
            ),
            current=current_card,
            ranking_weights=weights,
            recipes_available=settings.openai_enabled,
        )

    top = cards[0]
    if current is not None:
        message = (
            f"Based on your cooking intent, we found a more sustainable and suitable "
            f"alternative to {current.name}."
        )
    else:
        message = f"{top.name} is the best-ranked choice on file for {method_word}."
    return SmartSwapOut(
        intent=intent,
        status="SWAP_FOUND",
        message=message,
        current=current_card,
        recommended=top,
        alternatives=cards[1 : request.limit + 1],
        ranking_weights=weights,
        recipes_available=settings.openai_enabled,
    )
