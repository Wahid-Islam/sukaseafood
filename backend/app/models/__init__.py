"""SQLAlchemy ORM models for canonical seafood records."""

from datetime import date

from sqlalchemy import (
    Boolean,
    Date,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class SeafoodItem(Base):
    """Canonical seafood entity used by all Iteration 1 epics."""

    __tablename__ = "seafood_items"

    fish_id: Mapped[str] = mapped_column(String(32), primary_key=True)
    scientific_name: Mapped[str] = mapped_column(String(128), nullable=False)
    primary_common_name: Mapped[str] = mapped_column(String(128), nullable=False)
    fish_type: Mapped[str] = mapped_column(String(64), default="")
    common_in: Mapped[str] = mapped_column(String(128), default="Malaysia")
    market_availability: Mapped[str] = mapped_column(String(64), default="Year-round")
    about: Mapped[str] = mapped_column(Text, default="")
    image_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    cv_class: Mapped[str] = mapped_column(String(64), unique=True)
    pricecatcher_item_code: Mapped[int | None] = mapped_column(Integer, nullable=True)

    aliases: Mapped[list["SeafoodAlias"]] = relationship(back_populates="seafood")
    sustainability: Mapped["SustainabilityRecord | None"] = relationship(
        back_populates="seafood",
        uselist=False,
    )
    cooking: Mapped[list["CookingSuitability"]] = relationship(
        back_populates="seafood",
    )
    price_observations: Mapped[list["PriceObservation"]] = relationship(
        back_populates="seafood",
    )


class SeafoodAlias(Base):
    """Local names and search aliases mapped to a fish_id."""

    __tablename__ = "seafood_aliases"
    __table_args__ = (UniqueConstraint("alias", name="uq_alias"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    fish_id: Mapped[str] = mapped_column(
        ForeignKey("seafood_items.fish_id"),
        nullable=False,
    )
    alias: Mapped[str] = mapped_column(String(128), nullable=False)
    language: Mapped[str] = mapped_column(String(32), default="ms")

    seafood: Mapped[SeafoodItem] = relationship(back_populates="aliases")


class SustainabilityRecord(Base):
    """WWF Save Our Seafood classification for a species."""

    __tablename__ = "sustainability_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    fish_id: Mapped[str] = mapped_column(
        ForeignKey("seafood_items.fish_id"),
        unique=True,
        nullable=False,
    )
    classification: Mapped[str] = mapped_column(String(32), nullable=False)
    origin: Mapped[str] = mapped_column(String(128), default="Malaysia")
    production_method: Mapped[str] = mapped_column(String(128), default="")
    explanation: Mapped[str] = mapped_column(Text, default="")
    why_it_matters: Mapped[str] = mapped_column(Text, default="")
    source_name: Mapped[str] = mapped_column(
        String(128),
        default="WWF Save Our Seafood",
    )
    source_url: Mapped[str] = mapped_column(
        String(512),
        default="https://www.saveourseafood.my/",
    )
    verified: Mapped[bool] = mapped_column(Boolean, default=True)

    seafood: Mapped[SeafoodItem] = relationship(back_populates="sustainability")


class CookingSuitability(Base):
    """Cooking-method suitability scores for recommendations."""

    __tablename__ = "cooking_suitability"
    __table_args__ = (
        UniqueConstraint("fish_id", "method", name="uq_fish_method"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    fish_id: Mapped[str] = mapped_column(
        ForeignKey("seafood_items.fish_id"),
        nullable=False,
    )
    method: Mapped[str] = mapped_column(String(64), nullable=False)
    suitability_score: Mapped[float] = mapped_column(Float, default=0.0)
    rationale: Mapped[str] = mapped_column(Text, default="")
    verified: Mapped[bool] = mapped_column(Boolean, default=True)

    seafood: Mapped[SeafoodItem] = relationship(back_populates="cooking")


class PriceObservation(Base):
    """Observed price context derived from OpenDOSM PriceCatcher."""

    __tablename__ = "price_observations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    fish_id: Mapped[str] = mapped_column(
        ForeignKey("seafood_items.fish_id"),
        nullable=False,
    )
    observed_date: Mapped[date] = mapped_column(Date, nullable=False)
    price_rm_per_kg: Mapped[float] = mapped_column(Float, nullable=False)
    premise_state: Mapped[str] = mapped_column(String(64), default="")
    premise_type: Mapped[str] = mapped_column(String(64), default="")
    note: Mapped[str] = mapped_column(String(256), default="Observed price context")

    seafood: Mapped[SeafoodItem] = relationship(back_populates="price_observations")


class SupplyContext(Base):
    """Broader marine fish landings / supply context (not species forecasts)."""

    __tablename__ = "supply_context"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    fish_id: Mapped[str] = mapped_column(
        ForeignKey("seafood_items.fish_id"),
        unique=True,
        nullable=False,
    )
    summary: Mapped[str] = mapped_column(Text, default="")
    trend_label: Mapped[str] = mapped_column(String(64), default="Unavailable")
    source_name: Mapped[str] = mapped_column(
        String(128),
        default="OpenDOSM Fish Landings",
    )
