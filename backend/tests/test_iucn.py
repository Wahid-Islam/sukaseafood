"""IUCN payload parsing. Live token calls are skipped under pytest."""

from app.services.iucn import (
    _assessment_url,
    _latest_assessment,
    _v4_category,
    _v4_trend,
)


def test_latest_assessment_prefers_latest_flag():
    payload = {
        "assessments": [
            {
                "assessment_id": 1,
                "latest": False,
                "year_published": "2011",
                "red_list_category_code": "NT",
            },
            {
                "assessment_id": 9,
                "latest": True,
                "year_published": "2022",
                "red_list_category_code": "LC",
            },
        ]
    }
    latest = _latest_assessment(payload)
    assert latest is not None
    assert latest["assessment_id"] == 9
    assert _v4_category(latest) == "LC"


def test_v4_category_and_trend_from_assessment_detail():
    detail = {
        "red_list_category": {"code": "LC", "description": {"en": "Least Concern"}},
        "population_trend": {"description": {"en": "Stable"}},
        "taxon": {"sis_id": 170247},
        "url": "https://www.iucnredlist.org/species/170247/115656598",
    }
    assert _v4_category(detail) == "LC"
    assert _v4_trend(detail) == "Stable"
    assert _assessment_url("Rastrelliger kanagurta", {}, detail).endswith(
        "/species/170247/115656598"
    )
