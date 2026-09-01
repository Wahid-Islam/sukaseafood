"""Signed-in account routes: favourites.

Kept off the public catalogue router so a missing token is 401 rather than an
empty mock list. A newly created account has zero rows.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import AppUser
from app.schemas import SeafoodSummaryOut
from app.services import auth as auth_service
from app.services import favourites as favourites_service

router = APIRouter(prefix="/me", tags=["me"])


class FavouriteIn(BaseModel):
    fish_id: str = Field(min_length=1, max_length=64)


@router.get("/favourites", response_model=list[SeafoodSummaryOut])
async def list_favourites(
    user: AppUser = Depends(auth_service.get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[SeafoodSummaryOut]:
    return await favourites_service.list_favourites(db, user)


@router.post(
    "/favourites",
    response_model=SeafoodSummaryOut,
    status_code=status.HTTP_201_CREATED,
)
async def add_favourite(
    body: FavouriteIn,
    user: AppUser = Depends(auth_service.get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SeafoodSummaryOut:
    try:
        return await favourites_service.add_favourite(db, user, body.fish_id)
    except favourites_service.FavouriteNotFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc


@router.delete("/favourites/{fish_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_favourite(
    fish_id: str,
    user: AppUser = Depends(auth_service.get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    try:
        await favourites_service.remove_favourite(db, user, fish_id)
    except favourites_service.FavouriteNotFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
