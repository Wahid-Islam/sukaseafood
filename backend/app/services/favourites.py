"""Account-scoped favourites. Empty until the signed-in user saves a species."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AppUser, SeafoodItem, UserFavourite
from app.schemas import SeafoodSummaryOut
from app.services import seafood as seafood_service


class FavouriteNotFound(RuntimeError):
    """The requested species is not in the catalogue."""


async def list_favourites(
    session: AsyncSession, user: AppUser
) -> list[SeafoodSummaryOut]:
    stmt = (
        select(SeafoodItem)
        .join(UserFavourite, UserFavourite.seafood_item_id == SeafoodItem.seafood_item_id)
        .where(UserFavourite.app_user_id == user.id)
        .where(SeafoodItem.active.is_(True))
        .options(seafood_service._assessment_loader())
        .order_by(UserFavourite.created_at.desc(), SeafoodItem.code)
    )
    items = list(await session.scalars(stmt))
    return [seafood_service.to_summary(item) for item in items]


async def add_favourite(
    session: AsyncSession, user: AppUser, fish_id: str
) -> SeafoodSummaryOut:
    item = await seafood_service.get_seafood_by_id(session, fish_id)
    if item is None:
        raise FavouriteNotFound(f"Seafood item {fish_id!r} was not found.")

    existing = await session.get(UserFavourite, (user.id, item.seafood_item_id))
    if existing is None:
        session.add(
            UserFavourite(app_user_id=user.id, seafood_item_id=item.seafood_item_id)
        )
        await session.commit()

    # Reload with WWF so the card matches /seafood.
    item = await seafood_service.get_seafood_by_id(session, item.code)
    assert item is not None
    return seafood_service.to_summary(item)


async def remove_favourite(
    session: AsyncSession, user: AppUser, fish_id: str
) -> None:
    item = await seafood_service.get_seafood_by_id(session, fish_id)
    if item is None:
        raise FavouriteNotFound(f"Seafood item {fish_id!r} was not found.")

    row = await session.get(UserFavourite, (user.id, item.seafood_item_id))
    if row is not None:
        await session.delete(row)
        await session.commit()
