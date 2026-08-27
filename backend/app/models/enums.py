"""Python mirrors of the PostgreSQL enum types defined in the I1 schema.

Each class name matches its `*_enum` type in Postgres, and each member's VALUE
matches the label stored in the database. SQLAlchemy is configured with
`native_enum=True` and `create_type=False` throughout: the enum types are owned
by the SQL schema, not by the ORM, so Python can never silently create or alter
a type that the DBAs applied.
"""

from enum import Enum


class LocationLevel(str, Enum):
    """Granularity of a `location` row."""

    STATE = "STATE"
    DISTRICT = "DISTRICT"


class SeafoodAliasType(str, Enum):
    """What kind of name an alias is — drives search ranking and display."""

    MALAY = "MALAY"
    ENGLISH_COMMON = "ENGLISH_COMMON"
    SCIENTIFIC = "SCIENTIFIC"
    MARKET = "MARKET"
    SPELLING = "SPELLING"


class CollectionMethod(str, Enum):
    """How a source snapshot was obtained — part of the evidence trail."""

    OFFICIAL_DOWNLOAD = "OFFICIAL_DOWNLOAD"
    MANUAL_PDF_TRANSCRIPTION = "MANUAL_PDF_TRANSCRIPTION"
    TEAM_CURATED = "TEAM_CURATED"
    MODEL_ARTIFACT = "MODEL_ARTIFACT"


class SustainabilityRating(str, Enum):
    """WWF Save Our Seafood rating.

    There is deliberately no UNDETERMINED member. "We don't know" is expressed
    by the ABSENCE of a `wwf_assessment` row, so an unrated species can never be
    confused with a species that was assessed and found acceptable.
    """

    BEST_CHOICE = "BEST_CHOICE"
    REDUCE = "REDUCE"
    AVOID = "AVOID"


class ProductForm(str, Enum):
    """Form a PriceCatcher item is sold in — whole fish and fillet are not
    price-comparable, so this gates which items may be averaged together."""

    WHOLE = "WHOLE"
    CUT = "CUT"
    FILLET = "FILLET"
    HEAD = "HEAD"
    COOKED = "COOKED"
    OTHER = "OTHER"


class PriceMappingType(str, Enum):
    """How confidently a PriceCatcher item maps to a canonical species."""

    EXACT = "EXACT"
    COMMON_NAME = "COMMON_NAME"
    MARKET_VARIANT = "MARKET_VARIANT"
    MARKET_GROUP = "MARKET_GROUP"


class PriceQuality(str, Enum):
    """Whether a computed price summary may be shown to a user.

    INSUFFICIENT_DATA is a valid product state: the UI says so rather than
    displaying a median computed from two observations in one shop.
    """

    DISPLAYABLE = "DISPLAYABLE"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"
    REJECTED = "REJECTED"


class RecipeMappingType(str, Enum):
    """How a recipe was linked to a species."""

    EXACT = "EXACT"
    COMMON_NAME = "COMMON_NAME"
    MANUAL_CURATED = "MANUAL_CURATED"
