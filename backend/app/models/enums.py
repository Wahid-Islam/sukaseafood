"""Python mirrors of the PostgreSQL enum types defined in the V3 schema.

Each class name matches its `*_enum` type in Postgres, and each member's VALUE
matches the label stored in the database. SQLAlchemy is configured with
`native_enum=True` and `create_type=False` throughout: the enum types are owned
by the SQL schema, not by the ORM.
"""

from enum import Enum


class LocationLevel(str, Enum):
    STATE = "STATE"
    DISTRICT = "DISTRICT"


class SeafoodAliasType(str, Enum):
    MALAY = "MALAY"
    ENGLISH_COMMON = "ENGLISH_COMMON"
    SCIENTIFIC = "SCIENTIFIC"
    MARKET = "MARKET"
    SPELLING = "SPELLING"


class CollectionMethod(str, Enum):
    OFFICIAL_DOWNLOAD = "OFFICIAL_DOWNLOAD"
    MANUAL_PDF_TRANSCRIPTION = "MANUAL_PDF_TRANSCRIPTION"
    TEAM_CURATED = "TEAM_CURATED"
    MODEL_ARTIFACT = "MODEL_ARTIFACT"


class SustainabilityRating(str, Enum):
    """WWF Save Our Seafood rating.

    No UNDETERMINED member — absence of a wwf_assessment row means undetermined.
    """

    BEST_CHOICE = "BEST_CHOICE"
    REDUCE = "REDUCE"
    AVOID = "AVOID"


class ProductForm(str, Enum):
    WHOLE = "WHOLE"
    CUT = "CUT"
    FILLET = "FILLET"
    HEAD = "HEAD"
    COOKED = "COOKED"
    OTHER = "OTHER"


class PriceMappingType(str, Enum):
    EXACT = "EXACT"
    COMMON_NAME = "COMMON_NAME"
    MARKET_VARIANT = "MARKET_VARIANT"
    MARKET_GROUP = "MARKET_GROUP"
    PROXY = "PROXY"


class AggregationRule(str, Enum):
    SEPARATE = "SEPARATE"
    COMBINE = "COMBINE"
    DEFAULT_ONLY = "DEFAULT_ONLY"
    PROXY = "PROXY"


class MappingConfidence(str, Enum):
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


class PriceQuality(str, Enum):
    DISPLAYABLE = "DISPLAYABLE"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"
    REJECTED = "REJECTED"


class PeriodType(str, Enum):
    WEEK = "WEEK"
    MONTH = "MONTH"
    QUARTER = "QUARTER"


class RecipeMappingType(str, Enum):
    EXACT = "EXACT"
    COMMON_NAME = "COMMON_NAME"
    MANUAL_CURATED = "MANUAL_CURATED"
