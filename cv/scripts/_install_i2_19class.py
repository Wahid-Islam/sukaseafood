"""One-shot: copy the I2 19-class package into sukaseafood_cv_handoff.

class_index stays frozen. class_code is rewritten to the 54-fish WWF
catalogue identifiers so the scanner joins the right seafood_item row.
The package's placeholder SF013-SF026 collide with Demuduk / Siakap Putih /
Tongkol / Chinook and must not be used as join keys.
"""

from __future__ import annotations

import json
import shutil
import uuid
from pathlib import Path

SRC = Path(__file__).resolve().parents[1] / (
    "sukaSeafood_cv_backend_i2_19class_20260916"
    "/sukaSeafood_cv_backend_i2_19class_20260916"
)
DST = Path(__file__).resolve().parents[1] / "sukaseafood_cv_handoff"
NS = uuid.UUID("6f9619ff-8b86-d011-b42d-00c04fc964ff")

CODE_BY_LABEL = {
    "Alaskan Pollock": "SF016",
    "Atlantic Cod": "SF019",
    "Atlantic Salmon": "SF020",
    "Bawal Hitam": "SF002",
    "Cencaru": "SF007",
    "Ikan Merah": "SF003",
    "Jenahak": "SF008",
    "Kembung / Pelaling": "SF001",
    "Kerapu Bintik": "SF005",
    "Kerapu Harimau": "SF037",
    "Kerapu Kertang": "SF038",
    "Kerapu Lumpur": "SF039",
    "Kerapu Tikus": "SF041",
    "Kunyit-kunyit": "SF044",
    "Mameng": "SF046",
    "Siakap Merah": "SF051",
    "Siakap Putih": "SF014",
    "Tenggiri": "SF012",
    "Tilapia": "SF004",
}


def main() -> int:
    if not (SRC / "model.onnx").is_file():
        raise SystemExit(f"missing ONNX at {SRC / 'model.onnx'}")

    DST.mkdir(parents=True, exist_ok=True)
    for name in (
        "model.onnx",
        "preprocessing.json",
        "model_card.json",
        "model_manifest.json",
        "requirements-inference.txt",
    ):
        shutil.copy2(SRC / name, DST / name)
        print(f"copied {name}  {(DST / name).stat().st_size} bytes")

    raw = json.loads((SRC / "class_map.json").read_text(encoding="utf-8"))
    missing = [c["label"] for c in raw["classes"] if c["label"] not in CODE_BY_LABEL]
    if missing:
        raise SystemExit(f"unmapped labels: {missing}")
    indexes = [c["class_index"] for c in raw["classes"]]
    if indexes != list(range(19)):
        raise SystemExit(f"class indices are not 0..18: {indexes}")

    classes = []
    for c in raw["classes"]:
        code = CODE_BY_LABEL[c["label"]]
        classes.append(
            {
                "class_index": c["class_index"],
                "class_code": code,
                "fish_id": code,
                "seafood_item_id": str(uuid.uuid5(NS, f"seafood_item:{code}")),
                "label": c["label"],
                "canonical_name_ms": c.get("canonical_name_ms", c["label"]),
                "display_name_en": c["display_name_en"],
                "scientific_name": c["scientific_name"],
                "wwf_row_id": c.get("wwf_row_id"),
                "database_mapping_status": "linked",
            }
        )

    payload = {
        "model_version": raw["model_version"],
        "classes": classes,
        "catalogue_code_note": (
            "class_index is frozen from the ONNX export. class_code/fish_id "
            "are the 54-fish WWF catalogue identifiers, not the package "
            "placeholder SF013-SF026."
        ),
    }
    (DST / "class_map.json").write_text(
        json.dumps(payload, indent=2) + "\n", encoding="utf-8"
    )

    card = json.loads((DST / "model_card.json").read_text(encoding="utf-8"))
    card["class_mapping_status"] = {"linked": 19, "pending": 0}
    (DST / "model_card.json").write_text(
        json.dumps(card, indent=2) + "\n", encoding="utf-8"
    )

    expected_sf001 = "ae00df08-2bc0-5341-97e5-93b8b45d450b"
    got_sf001 = str(uuid.uuid5(NS, "seafood_item:SF001"))
    if got_sf001 != expected_sf001:
        raise SystemExit(f"uuid5 mismatch for SF001: {got_sf001}")

    for c in classes:
        print(f"  {c['class_index']:2d} {c['class_code']}  {c['label']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
