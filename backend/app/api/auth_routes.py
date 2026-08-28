"""Auth API: signup / login / me — PostgreSQL app_user only."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, EmailStr, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import AppUser
from app.services import auth as auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


class SignUpIn(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)


class LoginIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserOut(BaseModel):
    id: str
    name: str
    email: str
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class AuthOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


def _to_user_out(user: AppUser) -> UserOut:
    return UserOut(
        id=str(user.id),
        name=user.name,
        email=user.email,
        created_at=user.created_at,
    )


@router.post("/signup", response_model=AuthOut, status_code=status.HTTP_201_CREATED)
async def signup(body: SignUpIn, db: AsyncSession = Depends(get_db)) -> AuthOut:
    email = body.email.strip().lower()
    existing = await auth_service.get_user_by_email(db, email)
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="That email is already registered. Try signing in.",
        )

    user = AppUser(
        name=body.name.strip(),
        email=email,
        password_hash=auth_service.hash_password(body.password),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(user)
    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="That email is already registered. Try signing in.",
        ) from exc
    await db.refresh(user)

    token = auth_service.create_access_token(user.id)
    return AuthOut(access_token=token, user=_to_user_out(user))


@router.post("/login", response_model=AuthOut)
async def login(body: LoginIn, db: AsyncSession = Depends(get_db)) -> AuthOut:
    user = await auth_service.get_user_by_email(db, body.email)
    if user is None or not auth_service.verify_password(
        body.password, user.password_hash
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email or password is incorrect.",
        )
    token = auth_service.create_access_token(user.id)
    return AuthOut(access_token=token, user=_to_user_out(user))


@router.get("/me", response_model=UserOut)
async def me(user: AppUser = Depends(auth_service.get_current_user)) -> UserOut:
    return _to_user_out(user)
