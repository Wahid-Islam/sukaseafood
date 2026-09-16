"""Epic 4 routes: Cooking Intent -> Smart Swap -> Recipe."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas import (
    RecipeGenerateOut,
    RecipeGenerateRequest,
    SmartSwapOut,
    SmartSwapRequest,
)
from app.services import openai_client
from app.services import recipes as recipe_service
from app.services import smart_swap as smart_swap_service

router = APIRouter(tags=["epic4-cooking"])


def _error(code: str, message: str) -> dict:
    return {"error": {"code": code, "message": message, "details": {}}}


@router.post("/smart-swap", response_model=SmartSwapOut)
async def smart_swap(
    body: SmartSwapRequest,
    db: AsyncSession = Depends(get_db),
) -> SmartSwapOut:
    """Parse a cooking intent and rank more sustainable, suitable alternatives.

    Business outcomes (`SWAP_FOUND`, `ALREADY_GOOD`, `NO_BETTER_OPTION`,
    `NEEDS_INTENT`) are all HTTP 200 — each has its own copy on the screen.
    """
    if body.fish_id is not None and body.fish_id.strip():
        # Validate early so a typo is a 404, not a silent "no current fish".
        from app.services import seafood as seafood_service

        item = await seafood_service.get_seafood_by_id(db, body.fish_id, relations=False)
        if item is None:
            raise HTTPException(
                status_code=404,
                detail=_error("SEAFOOD_NOT_FOUND", "Seafood item was not found."),
            )
        body = body.model_copy(update={"fish_id": item.code})
    return await smart_swap_service.smart_swap(db, body)


@router.post("/recipes/generate", response_model=RecipeGenerateOut)
async def generate_recipes(
    body: RecipeGenerateRequest,
    db: AsyncSession = Depends(get_db),
) -> RecipeGenerateOut:
    """Generate recipes for the chosen fish and cooking intent (OpenAI).

    503 RECIPE_UNAVAILABLE  no OPENAI_API_KEY on this server
    502 RECIPE_GENERATION_FAILED  OpenAI errored, timed out or returned junk
    """
    try:
        return await recipe_service.generate_recipes(db, body)
    except recipe_service.FishNotFound as exc:
        raise HTTPException(404, detail=_error("SEAFOOD_NOT_FOUND", str(exc))) from exc
    except openai_client.OpenAIUnavailable as exc:
        raise HTTPException(503, detail=_error("RECIPE_UNAVAILABLE", str(exc))) from exc
    except openai_client.OpenAIError as exc:
        raise HTTPException(
            502, detail=_error("RECIPE_GENERATION_FAILED", str(exc))
        ) from exc
