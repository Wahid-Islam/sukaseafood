"""Price forecast read service (Step 33C).

Serving only. Every number returned here was computed upstream by the R
forecasting pipeline and stored by db/seed/09_price_forecast.sql. Nothing in
this module models, re-ranges, re-dates or re-interprets a forecast — the
division of labour in the handoff is explicit, and re-deriving any of it in
Python would mean the app could disagree with the validated engine output.

Two selection rules that decide what a shopper actually sees:

  * Only the ACTIVE forecast_model_version is served. Superseded runs stay in
    the table for audit rather than being deleted, so filtering on `active` is
    what keeps a stale forecast off the screen.
  * Weeks are returned ascending from the nearest, and the caller cannot ask
    for more than the horizon that was actually generated.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import ForecastModelVersion, Location, PriceForecast, SeafoodItem
from app.schemas import (
    ForecastLocationOut,
    ForecastModelOut,
    ForecastReferenceOut,
    ForecastWeekOut,
    PriceForecastOut,
)

DEFAULT_WEEKS = 4

# Human wording for the stored codes. The database keeps codes so that a copy
# edit can never change what a row means; these labels are presentation.
#
# NO_STRONG_SIGNAL must not be rendered as "Stable" or "Around current levels".
# The engine is saying it has no validated evidence of a move, which is a
# weaker and more honest claim than predicting the price will hold.
DIRECTION_LABELS: dict[str, str] = {
    "LIKELY_INCREASE": "Likely to increase",
    "LIKELY_DECREASE": "Likely to decrease",
    "NO_STRONG_SIGNAL": "No strong directional signal",
}

# Where the forecast band sits relative to the reference price. Separate from
# direction: a band can straddle the current price while the validated
# directional read still says "no signal".
RANGE_LABELS: dict[str, str] = {
    "AROUND_CURRENT_LEVELS": "Around current levels",
    "ABOVE_CURRENT_LEVELS": "Above current levels",
    "BELOW_CURRENT_LEVELS": "Below current levels",
}


class ForecastUnavailable(RuntimeError):
    """No current forecast for this fish and location.

    Distinct from "fish does not exist": most species have no forecast because
    the eligibility rules excluded them for thin data, which is a normal state
    the UI should explain rather than an error.
    """


class InvalidLocation(RuntimeError):
    """The requested location is not a state we forecast for."""


def _float(value: Decimal | None) -> float | None:
    return None if value is None else float(value)


async def resolve_location(
    session: AsyncSession,
    location_id: str | None,
) -> Location:
    """The location to forecast for.

    Defaults to Selangor because that is the production scope of the deployed
    engine — the configuration records `location_scope: Selangor`. Defaulting
    silently to "any location with rows" would let the app show a Selangor
    price under another state's name.
    """
    if location_id:
        # Parse before touching Postgres. asyncpg + a UUID column will spend
        # ~15s then 500 on a string like "selangor"; a syntactically valid but
        # unknown UUID already returned 400 INVALID_LOCATION. Reject the
        # malformed case at the same boundary.
        try:
            location_uuid = uuid.UUID(str(location_id).strip())
        except (ValueError, AttributeError, TypeError) as exc:
            raise InvalidLocation(
                "location_id must be a UUID."
            ) from exc
        location = await session.scalar(
            select(Location).where(Location.location_id == location_uuid)
        )
        if location is None:
            raise InvalidLocation(f"Unknown location_id {location_id!r}.")
        return location

    location = await session.scalar(
        select(Location).where(
            Location.state_name.ilike("Selangor"),
            Location.district_name.is_(None),
        )
    )
    if location is None:
        raise ForecastUnavailable("Selangor is not seeded; no forecast scope available.")
    return location


async def active_model_version(session: AsyncSession) -> ForecastModelVersion | None:
    """The one model version whose forecasts may be served."""
    return await session.scalar(
        select(ForecastModelVersion)
        .where(ForecastModelVersion.active.is_(True))
        .order_by(ForecastModelVersion.created_at.desc())
        .limit(1)
    )


async def get_forecast(
    session: AsyncSession,
    item: SeafoodItem,
    location_id: str | None = None,
    weeks: int = DEFAULT_WEEKS,
) -> PriceForecastOut:
    """Build the 33C forecast payload for one canonical species.

    Raises ForecastUnavailable when the species has no rows under the active
    model version, which is the common case: the engine forecasts only the
    fish that pass its data-eligibility rules.
    """
    location = await resolve_location(session, location_id)

    model = await active_model_version(session)
    if model is None:
        raise ForecastUnavailable(
            "No active forecast model version. Apply db/seed/09_price_forecast.sql."
        )

    stmt = (
        select(PriceForecast)
        .options(selectinload(PriceForecast.forecast_model_version))
        .where(
            PriceForecast.seafood_item_id == item.seafood_item_id,
            PriceForecast.location_id == location.location_id,
            PriceForecast.forecast_model_version_id == model.forecast_model_version_id,
        )
        # Nearest week first, per the contract's ordering rule.
        .order_by(PriceForecast.forecast_week_start.asc())
        .limit(max(1, weeks))
    )
    rows = list((await session.scalars(stmt)).all())

    if not rows:
        raise ForecastUnavailable(
            f"No current forecast for {item.code} in {location.state_name}."
        )

    weeks_out = [
        ForecastWeekOut(
            forecast_week_start=row.forecast_week_start,
            horizon_weeks=row.horizon_weeks,
            expected_price=float(row.expected_price),
            lower_bound=float(row.lower_bound),
            upper_bound=float(row.upper_bound),
            outlook=row.outlook,
            outlook_label=_range_label(row.range_outlook),
            directional_outlook_label=DIRECTION_LABELS.get(row.outlook or ""),
            quality_status=row.quality_status,
            model_used=row.model_used,
        )
        for row in rows
    ]

    reference = _reference(rows[0])
    generated_at: datetime | None = rows[0].generated_at

    return PriceForecastOut(
        fish_id=item.code,
        seafood_item_id=item.seafood_item_id,
        canonical_name=item.canonical_name_ms,
        display_name=item.display_name_en,
        location=ForecastLocationOut(
            location_id=location.location_id,
            state_name=location.state_name,
        ),
        reference=reference,
        forecast=weeks_out,
        model=ForecastModelOut(
            model_version_id=model.forecast_model_version_id,
            version_name=model.version_name,
            algorithm=model.algorithm,
            interval_level=_float(model.interval_level),
        ),
        generated_at=generated_at,
    )


def _range_label(code: str | None) -> str | None:
    """Label for a range outlook, falling back to the raw code.

    An unmapped code is returned as-is rather than dropped: a new engine label
    should surface as something visibly unpolished, not vanish from the UI.
    """
    if not code:
        return None
    return RANGE_LABELS.get(code, code.replace("_", " ").capitalize())


def _reference(row: PriceForecast) -> ForecastReferenceOut:
    """The observed price and week the forecast was anchored to.

    The series is weekly and `row` is the nearest forecast week, so the week
    the reference price belongs to is exactly seven days earlier. Deriving it
    from the forecast week rather than from `forecast_origin_date` avoids
    weekday arithmetic: the origin date is when the run executed, which is not
    week-aligned and would misdate the price the shopper compares against.
    """
    week_start: date | None = None
    if row.forecast_week_start is not None:
        week_start = row.forecast_week_start - timedelta(days=7)
    return ForecastReferenceOut(
        week_start=week_start,
        price=_float(row.current_reference_price),
    )


__all__ = [
    "DEFAULT_WEEKS",
    "ForecastUnavailable",
    "InvalidLocation",
    "active_model_version",
    "get_forecast",
    "resolve_location",
]
