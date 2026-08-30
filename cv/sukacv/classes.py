"""The classes the scanner can recognise.

Single source of truth for class_index -> class_code inside the CV package.
It must match cv_class_mapping in PostgreSQL exactly: the model emits an index,
the backend resolves that index to a seafood_item_id, and if the two disagree
the app names the wrong fish with full confidence.

Changing the order requires a NEW model version and a new set of
cv_class_mapping rows. Never reorder in place.

class_code is the same string as seafood_item.code. That is the entire join:
the model knows codes, the database knows UUIDs, and cv_class_mapping is the
only place the two meet. The CV package never sees a seafood_item_id — which
is what lets a better model drop in without touching the API.

These nine are the species the image corpus covers. seafood_item also holds
SF003 Ikan Merah, SF004 Tilapia and SF005 Kerapu Bintik, which have canonical
rows and downstream data but no training images; they carry supports_cv=FALSE
and are deliberately absent here.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SeafoodClass:
    class_index: int
    class_code: str
    label: str
    scientific_name: str
    dataset_dir: str


# Index order is frozen with the artifact. Sorted by class_code so the order is
# reproducible from the catalogue rather than from whatever order a directory
# listing happened to return.
CLASSES: tuple[SeafoodClass, ...] = (
    SeafoodClass(0, "SF001", "Kembung / Pelaling", "Rastrelliger kanagurta", "KEMBUNG"),
    SeafoodClass(1, "SF002", "Bawal Hitam", "Parastromateus niger", "BAWAL_HITAM"),
    SeafoodClass(2, "SF006", "Bawal Putih", "Pampus argenteus", "BAWAL_PUTIH"),
    SeafoodClass(3, "SF007", "Cencaru", "Megalaspis cordyla", "CENCARU"),
    SeafoodClass(4, "SF008", "Jenahak", "Lutjanus johnii", "JENAHAK"),
    SeafoodClass(5, "SF009", "Kerisi", "Nemipterus japonicus", "KERISI"),
    SeafoodClass(6, "SF010", "Pelata", "Alepes melanoptera", "PELATA"),
    SeafoodClass(7, "SF011", "Selar Kuning", "Selaroides leptolepis", "SELAR_KUNING"),
    SeafoodClass(8, "SF012", "Tenggiri", "Scomberomorus commerson", "TENGGIRI"),
)

NUM_CLASSES = len(CLASSES)
CODE_TO_INDEX = {c.class_code: c.class_index for c in CLASSES}
INDEX_TO_CODE = {c.class_index: c.class_code for c in CLASSES}
INDEX_TO_LABEL = {c.class_index: c.label for c in CLASSES}
DATASET_DIR_TO_CODE = {c.dataset_dir: c.class_code for c in CLASSES}

# Species that have a canonical seafood_item row but no images, so the model
# cannot return them. Recorded here so tooling can say why, rather than leaving
# someone to wonder where Tilapia went.
NOT_YET_SCANNABLE = {
    "SF003": "Ikan Merah (Lutjanus sebae)",
    "SF004": "Tilapia (Oreochromis niloticus)",
    "SF005": "Kerapu Bintik (Epinephelus coioides)",
}

# Folder and label names a dataset might arrive with, resolved to class codes.
# Matching is case- and punctuation-insensitive. A name that does not resolve is
# reported to a human rather than guessed at — a folder dropped into the
# nearest-looking class teaches the model to be confidently wrong.
ALIASES: dict[str, str] = {
    # SF001 — Rastrelliger kanagurta
    "sf001": "SF001", "kembung": "SF001", "ikankembung": "SF001",
    "pelaling": "SF001", "kembungpelaling": "SF001",
    "indianmackerel": "SF001",
    "rastrelligerkanagurta": "SF001", "rastrelliger": "SF001",
    # SF002 — Parastromateus niger
    "sf002": "SF002", "bawalhitam": "SF002", "ikanbawalhitam": "SF002",
    "blackpomfret": "SF002",
    "parastromateusniger": "SF002", "parastromateus": "SF002",
    # SF006 — Pampus argenteus
    "sf006": "SF006", "bawalputih": "SF006", "ikanbawalputih": "SF006",
    "silverpomfret": "SF006", "whitepomfret": "SF006",
    "pampusargenteus": "SF006", "pampus": "SF006",
    # SF007 — Megalaspis cordyla
    "sf007": "SF007", "cencaru": "SF007", "ikancencaru": "SF007",
    "chencaru": "SF007", "hardtailscad": "SF007", "torpedoscad": "SF007",
    "megalaspiscordyla": "SF007", "megalaspis": "SF007",
    # SF008 — Lutjanus johnii
    "sf008": "SF008", "jenahak": "SF008", "ikanjenahak": "SF008",
    "johnssnapper": "SF008", "johnsnapper": "SF008", "goldensnapper": "SF008",
    "lutjanusjohnii": "SF008",
    # SF009 — Nemipterus japonicus
    "sf009": "SF009", "kerisi": "SF009", "ikankerisi": "SF009",
    "japanesethreadfinbream": "SF009", "threadfinbream": "SF009",
    "nemipterusjaponicus": "SF009", "nemipterus": "SF009",
    # SF010 — Alepes melanoptera
    "sf010": "SF010", "pelata": "SF010", "ikanpelata": "SF010",
    "blackfinscad": "SF010",
    "alepesmelanoptera": "SF010", "alepes": "SF010",
    # SF011 — Selaroides leptolepis
    "sf011": "SF011", "selarkuning": "SF011", "ikanselarkuning": "SF011",
    "yellowstripescad": "SF011",
    "selaroidesleptolepis": "SF011", "selaroides": "SF011",
    # SF012 — Scomberomorus commerson
    "sf012": "SF012", "tenggiri": "SF012", "ikantenggiri": "SF012",
    "narrowbarredspanishmackerel": "SF012", "spanishmackerel": "SF012",
    "scomberomoruscommerson": "SF012", "scomberomorus": "SF012",
}

# Names belonging to a real catalogue species the model cannot recognise.
# Resolving these to None is correct, but doing so silently is not: callers
# should be able to distinguish "unknown fish" from "known fish, no training
# images yet".
ALIASES_NOT_SCANNABLE: dict[str, str] = {
    "sf003": "SF003", "ikanmerah": "SF003", "redsnapper": "SF003",
    "lutjanussebae": "SF003",
    "sf004": "SF004", "tilapia": "SF004", "ikantilapia": "SF004",
    "niletilapia": "SF004", "oreochromisniloticus": "SF004",
    "sf005": "SF005", "kerapubintik": "SF005", "kerapu": "SF005",
    "orangespottedgrouper": "SF005", "epinepheluscoioides": "SF005",
}


def normalise(name: str) -> str:
    """Strip everything that varies between people naming the same folder."""
    return "".join(ch for ch in name.lower() if ch.isalnum())


def resolve_class(name: str) -> str | None:
    """Folder or label -> class code, or None when the model cannot learn it."""
    key = normalise(name)
    if key in ALIASES:
        return ALIASES[key]
    # Tolerate decoration like "01_kembung_raw" or "selar kuning (fresh)".
    for alias, code in ALIASES.items():
        if len(alias) >= 6 and alias in key:
            return code
    return None


def explain_unresolved(name: str) -> str:
    """Why a name did not resolve. The two reasons are not the same problem."""
    key = normalise(name)
    for alias, code in ALIASES_NOT_SCANNABLE.items():
        if key == alias or (len(alias) >= 6 and alias in key):
            return (f"{NOT_YET_SCANNABLE[code]} is in the catalogue as {code} "
                    f"but has no training images, so the scanner cannot return it")
    return "not one of the species this model was trained on"


def class_map_json() -> list[dict]:
    """The class map shipped in the handoff package."""
    return [
        {
            "class_index": c.class_index,
            "class_code": c.class_code,
            "label": c.label,
            "scientific_name": c.scientific_name,
        }
        for c in CLASSES
    ]
