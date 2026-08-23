"""Seed data for the five Iteration 1 supported Malaysian seafood species."""

from datetime import date, timedelta

# Canonical IDs used by search, CV, WWF, price, and cooking.
SEED_SEAFOOD = [
    {
        "fish_id": "fish_kembung",
        "scientific_name": "Rastrelliger kanagurta",
        "primary_common_name": "Kembung / Pelaling",
        "fish_type": "Pelagic fish",
        "common_in": "Malaysia",
        "market_availability": "Year-round",
        "about": (
            "Indian mackerel widely sold in Malaysian wet markets and "
            "supermarkets. Common local names include kembung and pelaling."
        ),
        "image_url": None,
        "cv_class": "kembung",
        "pricecatcher_item_code": None,
        "aliases": [
            ("kembung", "ms"),
            ("ikan kembung", "ms"),
            ("pelaling", "ms"),
            ("indian mackerel", "en"),
            ("rastrelliger kanagurta", "scientific"),
        ],
        "sustainability": {
            "classification": "GOOD CHOICE",
            "origin": "Malaysia",
            "production_method": "Wild-caught / purse seine (verify locally)",
            "explanation": (
                "Mapped to WWF Save Our Seafood guidance for commonly "
                "available Malaysian pelagic species. Classification must "
                "be verified against the live WWF SOS listing before demo."
            ),
            "why_it_matters": (
                "Choosing better-rated seafood reduces pressure on "
                "overfished stocks and supports healthier oceans."
            ),
        },
        "supply": {
            "summary": (
                "Broader marine fish landings provide supply context only. "
                "This is not a species-level forecast."
            ),
            "trend_label": "Stable to slight decline",
        },
        "cooking": [
            ("grilling", 0.9, "Holds together well on the grill."),
            ("curry", 0.85, "Common in Malaysian fish curry."),
            ("pan-fry", 0.8, "Quick weeknight fry."),
            ("soup", 0.7, "Works in clear soups."),
            ("stir-fry", 0.55, "Better as steaks than shredded."),
        ],
        "base_price": 18.5,
    },
    {
        "fish_id": "fish_bawal_hitam",
        "scientific_name": "Parastromateus niger",
        "primary_common_name": "Bawal Hitam",
        "fish_type": "Demersal fish",
        "common_in": "Malaysia",
        "market_availability": "Year-round",
        "about": (
            "Black pomfret popular for steaming and Chinese-style preparations."
        ),
        "image_url": None,
        "cv_class": "bawal_hitam",
        "pricecatcher_item_code": None,
        "aliases": [
            ("bawal hitam", "ms"),
            ("ikan bawal hitam", "ms"),
            ("black pomfret", "en"),
            ("parastromateus niger", "scientific"),
        ],
        "sustainability": {
            "classification": "REDUCE",
            "origin": "Malaysia / regional",
            "production_method": "Wild-caught (method varies by supplier)",
            "explanation": (
                "Placeholder REDUCE classification pending verified WWF SOS "
                "extraction for black pomfret variants available in Malaysia."
            ),
            "why_it_matters": (
                "Reducing pressure on demersal stocks helps ecosystems "
                "recover from historical biomass declines."
            ),
        },
        "supply": {
            "summary": "Demersal landings context only; not a catch forecast.",
            "trend_label": "Pressure observed",
        },
        "cooking": [
            ("steaming", 0.95, "Classic steamed bawal preparation."),
            ("pan-fry", 0.8, "Crispy skin when pan-fried."),
            ("soup", 0.75, "Good for clear fish soup."),
            ("grilling", 0.6, "Possible but less common."),
            ("curry", 0.55, "Acceptable alternative."),
        ],
        "base_price": 32.0,
    },
    {
        "fish_id": "fish_ikan_merah",
        "scientific_name": "Lutjanus spp.",
        "primary_common_name": "Ikan Merah",
        "fish_type": "Reef / demersal fish",
        "common_in": "Malaysia",
        "market_availability": "Year-round",
        "about": (
            "Red snapper group commonly sold as ikan merah. Exact species "
            "varies; confirm locally when possible."
        ),
        "image_url": None,
        "cv_class": "ikan_merah",
        "pricecatcher_item_code": None,
        "aliases": [
            ("ikan merah", "ms"),
            ("merah", "ms"),
            ("red snapper", "en"),
            ("lutjanus", "scientific"),
        ],
        "sustainability": {
            "classification": "AVOID",
            "origin": "Malaysia / imported (varies)",
            "production_method": "Wild-caught (often mixed snapper)",
            "explanation": (
                "Many snapper fisheries face pressure. Treat as AVOID until "
                "a verified WWF SOS listing confirms otherwise for the "
                "specific product offered."
            ),
            "why_it_matters": (
                "Avoiding pressured reef species and choosing better-rated "
                "alternatives supports ecosystem recovery."
            ),
        },
        "supply": {
            "summary": "Reef/demersal context only; identity can be mixed.",
            "trend_label": "Caution",
        },
        "cooking": [
            ("steaming", 0.9, "Popular steamed dish."),
            ("grilling", 0.85, "Firm flesh for grilling."),
            ("curry", 0.7, "Works in rich curries."),
            ("pan-fry", 0.75, "Pan-fry friendly."),
            ("soup", 0.65, "Usable in soup bases."),
        ],
        "base_price": 38.0,
    },
    {
        "fish_id": "fish_tilapia",
        "scientific_name": "Oreochromis spp.",
        "primary_common_name": "Tilapia",
        "fish_type": "Farmed freshwater fish",
        "common_in": "Malaysia",
        "market_availability": "Year-round",
        "about": (
            "Widely farmed freshwater fish. Look for responsible farm "
            "practices / MyGAP where available."
        ),
        "image_url": None,
        "cv_class": "tilapia",
        "pricecatcher_item_code": None,
        "aliases": [
            ("tilapia", "en"),
            ("ikan tilapia", "ms"),
            ("oreochromis", "scientific"),
        ],
        "sustainability": {
            "classification": "GOOD CHOICE",
            "origin": "Malaysia (farmed)",
            "production_method": "Aquaculture",
            "explanation": (
                "Farmed tilapia is often a more sustainable everyday option "
                "when responsibly produced. Prefer certified / MyGAP farms "
                "when labelled."
            ),
            "why_it_matters": (
                "Responsible aquaculture can ease pressure on wild stocks "
                "while remaining affordable."
            ),
        },
        "supply": {
            "summary": "Aquaculture supply is generally steady year-round.",
            "trend_label": "Available",
        },
        "cooking": [
            ("grilling", 0.85, "Mild flavour for grilling."),
            ("pan-fry", 0.9, "Everyday pan-fry favourite."),
            ("soup", 0.8, "Common in fish soup."),
            ("curry", 0.75, "Absorbs curry flavours well."),
            ("stir-fry", 0.7, "Works cubed or filleted."),
        ],
        "base_price": 12.5,
    },
    {
        "fish_id": "fish_kerapu_bintik",
        "scientific_name": "Epinephelus spp.",
        "primary_common_name": "Kerapu Bintik",
        "fish_type": "Grouper / reef fish",
        "common_in": "Malaysia",
        "market_availability": "Seasonal / variable",
        "about": (
            "Spotted grouper sold as kerapu bintik. High-value species; "
            "verify sustainability for wild vs farmed product."
        ),
        "image_url": None,
        "cv_class": "kerapu_bintik",
        "pricecatcher_item_code": None,
        "aliases": [
            ("kerapu bintik", "ms"),
            ("kerapu", "ms"),
            ("spotted grouper", "en"),
            ("grouper", "en"),
            ("epinephelus", "scientific"),
        ],
        "sustainability": {
            "classification": "UNDETERMINED",
            "origin": "Malaysia / regional",
            "production_method": "Wild-caught or farmed (confirm at purchase)",
            "explanation": (
                "WWF mapping is ambiguous across grouper species and "
                "production methods. Returning UNDETERMINED rather than "
                "guessing."
            ),
            "why_it_matters": (
                "When sustainability is unclear, prefer better-documented "
                "alternatives or ask the seller about origin and method."
            ),
        },
        "supply": {
            "summary": "High-value reef fishery; supply is variable.",
            "trend_label": "Variable",
        },
        "cooking": [
            ("steaming", 0.95, "Premium steamed kerapu."),
            ("grilling", 0.8, "Firm steaks grill well."),
            ("soup", 0.7, "Used in rich soups."),
            ("curry", 0.65, "Works but often overkill for curry."),
            ("pan-fry", 0.7, "Pan-fry possible for fillets."),
        ],
        "base_price": 48.0,
    },
]


def build_price_series(base_price: float, days: int = 56) -> list[dict]:
    """Generate simple observed-price history for seed charts."""
    today = date(2026, 8, 23)
    points: list[dict] = []
    for i in range(days, -1, -7):
        # Mild oscillation so UI charts are non-empty.
        wave = ((days - i) % 21 - 10) * 0.08
        points.append(
            {
                "observed_date": today - timedelta(days=i),
                "price_rm_per_kg": round(base_price + wave, 2),
                "premise_state": "Wilayah Persekutuan",
                "premise_type": "Pasar Raya",
                "note": "Seed observed price context",
            }
        )
    return points
