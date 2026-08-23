"""Database seeding for Iteration 1 canonical seafood records."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    CookingSuitability,
    PriceObservation,
    SeafoodAlias,
    SeafoodItem,
    SupplyContext,
    SustainabilityRecord,
)
from app.seed.data import SEED_SEAFOOD, build_price_series


async def seed_database(session: AsyncSession) -> None:
    """Insert the five supported species if the table is empty."""
    existing = await session.scalar(select(SeafoodItem).limit(1))
    if existing is not None:
        return

    for item in SEED_SEAFOOD:
        seafood = SeafoodItem(
            fish_id=item["fish_id"],
            scientific_name=item["scientific_name"],
            primary_common_name=item["primary_common_name"],
            fish_type=item["fish_type"],
            common_in=item["common_in"],
            market_availability=item["market_availability"],
            about=item["about"],
            image_url=item["image_url"],
            cv_class=item["cv_class"],
            pricecatcher_item_code=item["pricecatcher_item_code"],
        )
        session.add(seafood)

        for alias, language in item["aliases"]:
            session.add(
                SeafoodAlias(
                    fish_id=item["fish_id"],
                    alias=alias,
                    language=language,
                )
            )

        sus = item["sustainability"]
        session.add(
            SustainabilityRecord(
                fish_id=item["fish_id"],
                classification=sus["classification"],
                origin=sus["origin"],
                production_method=sus["production_method"],
                explanation=sus["explanation"],
                why_it_matters=sus["why_it_matters"],
            )
        )

        supply = item["supply"]
        session.add(
            SupplyContext(
                fish_id=item["fish_id"],
                summary=supply["summary"],
                trend_label=supply["trend_label"],
            )
        )

        for method, score, rationale in item["cooking"]:
            session.add(
                CookingSuitability(
                    fish_id=item["fish_id"],
                    method=method,
                    suitability_score=score,
                    rationale=rationale,
                    verified=True,
                )
            )

        for point in build_price_series(item["base_price"]):
            session.add(
                PriceObservation(
                    fish_id=item["fish_id"],
                    observed_date=point["observed_date"],
                    price_rm_per_kg=point["price_rm_per_kg"],
                    premise_state=point["premise_state"],
                    premise_type=point["premise_type"],
                    note=point["note"],
                )
            )

    await session.commit()
