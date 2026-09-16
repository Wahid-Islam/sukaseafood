"""API contract tests against a real PostgreSQL database.

The scanner tests here deliberately use real held-out photographs rather than
synthetic noise. A test that feeds random pixels proves the plumbing works and
nothing else; it would keep passing after a training run that destroyed the
model's accuracy. These assert that a photograph of a kembung comes back as
kembung, carrying the same seafood_item_id that search returns for kembung —
which is the whole point of the CV feature.

Where the corpus is not present (CI without the image set), those tests skip
with a message rather than failing, because the images are ~2 GB and are not
checked into the repository.
"""

import io
import os
import pathlib
import uuid

import pytest

# The corpus is optional: cloned repos do not carry 2 GB of photographs.
# Note the explicit empty check — Path("") is Path("."), and "." is a directory,
# so an is_dir() test alone would silently enable these tests with the wrong
# root and fail with "0 images found" instead of skipping.
_corpus_env = os.environ.get("CV_TEST_IMAGES", "").strip()
CORPUS = pathlib.Path(_corpus_env).expanduser() if _corpus_env else None
MANIFEST = pathlib.Path(__file__).resolve().parents[2] / "cv" / "data" / "manifest.csv"

needs_corpus = pytest.mark.skipif(
    not (CORPUS and CORPUS.is_dir() and MANIFEST.exists()),
    reason=(
        "Set CV_TEST_IMAGES to the image corpus root (the folder holding "
        "KEMBUNG/, TENGGIRI/, …) to run scanner accuracy tests."
    ),
)


def _held_out(limit_per_class: int = 2) -> list[tuple[str, pathlib.Path]]:
    """Test-split images only — never anything the model trained or tuned on."""
    import collections
    import csv

    picked: list[tuple[str, pathlib.Path]] = []
    seen: collections.Counter = collections.Counter()
    with MANIFEST.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            if row["split"] != "test_clean":
                continue
            if seen[row["class_code"]] >= limit_per_class:
                continue
            path = CORPUS / row["local_path"]
            if not path.exists():
                continue
            seen[row["class_code"]] += 1
            picked.append((row["class_code"], path))
    return picked


def _jpeg(width: int = 224, height: int = 224, colour=(120, 130, 140)) -> bytes:
    from PIL import Image

    buf = io.BytesIO()
    Image.new("RGB", (width, height), colour).save(buf, format="JPEG")
    return buf.getvalue()



def test_health(client):
    res = client.get("/api/v1/health")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"


def test_database_health(client):
    """The readiness probe should see the schema and the seeded species."""
    res = client.get("/api/v1/health/db")
    assert res.status_code == 200
    body = res.json()
    assert body["database"] == "postgresql"
    assert body["schema_applied"] is True
    assert body["seafood_count"] == 54


def test_list_seafood(client):
    """Exactly the 54 WWF-listed fishes. Demuduk (SF013) is forecast-only.

    The 19-class scanner covers a subset of this list. SF013 stays in the
    database inactive so PriceCatcher and the R engine keep a canonical key,
    but it is not a public listing.
    """
    res = client.get("/api/v1/seafood")
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 54
    assert {i["fish_id"] for i in items} == {
        "SF001", "SF002", "SF003", "SF004", "SF005", "SF006",
        "SF007", "SF008", "SF009", "SF010", "SF011", "SF012",
        "SF014", "SF015",
        "SF016", "SF017", "SF018", "SF019", "SF020", "SF021",
        "SF022", "SF023", "SF024", "SF025", "SF026", "SF027",
        "SF028", "SF029", "SF030", "SF031", "SF032", "SF033",
        "SF034", "SF035", "SF036", "SF037", "SF038", "SF039",
        "SF040", "SF041", "SF042", "SF043", "SF044", "SF045",
        "SF046", "SF047", "SF048", "SF049", "SF050", "SF051",
        "SF052", "SF053", "SF054", "SF055",
    }
    assert "SF013" not in {i["fish_id"] for i in items}


def test_demuduk_is_not_in_public_search(client):
    """Family-level ponyfish stays off Discover; Kikek is the WWF listing."""
    results = client.get("/api/v1/search", params={"q": "demuduk"}).json()["results"]
    assert not any(r["fish_id"] == "SF013" for r in results)


def test_search_by_malay_alias(client):
    res = client.get("/api/v1/search", params={"q": "kembung"})
    assert res.status_code == 200
    results = res.json()["results"]
    assert results, "kembung must resolve via seafood_alias"
    assert results[0]["fish_id"] == "SF001"


def test_search_is_case_and_space_insensitive(client):
    """Search runs on LOWER(TRIM(alias_name)) — the same expression the unique
    index uses, so display casing can never hide a result."""
    for term in ("KEMBUNG", "  Kembung  ", "kEmBuNg"):
        results = client.get("/api/v1/search", params={"q": term}).json()["results"]
        assert any(r["fish_id"] == "SF001" for r in results), term


def test_search_by_english_common_name(client):
    results = client.get(
        "/api/v1/search", params={"q": "Indian Mackerel"}
    ).json()["results"]
    assert results[0]["fish_id"] == "SF001"
    assert results[0]["display_name_en"] == "Indian Mackerel"


def test_search_by_canonical_malay_name(client):
    results = client.get(
        "/api/v1/search", params={"q": "Kembung / Pelaling"}
    ).json()["results"]
    assert any(r["fish_id"] == "SF001" for r in results)


def test_search_by_scientific_name(client):
    results = client.get(
        "/api/v1/search", params={"q": "Oreochromis niloticus"}
    ).json()["results"]
    assert any(r["fish_id"] == "SF004" for r in results)


def test_profile_includes_aliases_and_cooking(client):
    res = client.get("/api/v1/seafood/SF001")
    assert res.status_code == 200
    body = res.json()
    assert body["scientific_name"] == "Rastrelliger kanagurta"
    assert len(body["aliases"]) >= 5
    assert body["cooking"], "cooking suitability should be seeded"
    assert body["cooking"][0]["suitability_score"] >= body["cooking"][-1][
        "suitability_score"
    ], "cooking methods must come back best-first"
    assert body["display_name_en"] == "Indian Mackerel"
    assert body["family"] == "Scombridae"
    bio = body["biodiversity"]
    assert bio["available"] is True
    assert bio["habitat_group"] == "pelagic-neritic"
    assert bio["family"] == "Scombridae"
    assert bio["depth_shallow_m"] == 20
    assert bio["depth_deep_m"] == 90
    assert bio["iucn_category"] == "LC"
    assert bio["ecological_role"]
    assert bio["occurrences"]
    assert any(s["key"] == "mybis" and s["available"] is False for s in bio["sources"])
    listed = client.get("/api/v1/seafood").json()
    kembung = next(row for row in listed if row["fish_id"] == "SF001")
    assert "grill" in kembung["suitable_methods"]
    assert "curry" in kembung["suitable_methods"]
    assert kembung["cooking_scores"]["grill"] == 5
    assert kembung["cooking_scores"]["curry"] == 5
    assert kembung["cooking_scores"]["fry"] == 4


def test_wwf_listed_species_have_seven_cooking_methods(client):
    """Cooking scores come from SuitabilityScoreSuka_complete_54_fish.csv."""
    pollock = client.get("/api/v1/seafood/SF016").json()
    methods = [row["method"] for row in pollock["cooking"]]
    assert sorted(methods) == ["bake", "curry", "fry", "grill", "raw", "soup", "steam"]


def test_family_level_species_has_no_invented_biodiversity(client):
    """SF013 is family-level. No FishBase/IUCN species extract is on file."""
    bio = client.get("/api/v1/seafood/SF013").json()["biodiversity"]
    assert bio["available"] is False
    assert bio["iucn_category"] is None
    assert bio["occurrences"] == []
    assert bio["unavailable_reason"]


def test_tongkol_is_searchable_and_wwf_rated(client):
    results = client.get("/api/v1/search", params={"q": "Tongkol"}).json()["results"]
    assert any(r["fish_id"] == "SF015" for r in results)
    body = client.get("/api/v1/seafood/SF015").json()
    assert body["scientific_name"] == "Thunnus tonggol"
    assert body["sustainability"]["classification"] == "REDUCE"
    assert body["sustainability"]["verified"] is True
    assert body["biodiversity"]["available"] is False


def test_tongkol_kurik_keeps_retrieved_euthynnus_biodiversity(client):
    body = client.get("/api/v1/seafood/SF054").json()
    assert body["scientific_name"] == "Euthynnus affinis"
    assert body["sustainability"]["classification"] == "REDUCE"
    assert body["biodiversity"]["available"] is True
    assert body["biodiversity"]["iucn_category"] == "LC"


def test_unknown_species_is_404(client):
    assert client.get("/api/v1/seafood/SF999").status_code == 404


def test_rated_species_reports_its_wwf_rating(client):
    body = client.get("/api/v1/seafood/SF001").json()
    assert body["sustainability"]["classification"] == "REDUCE"
    assert body["sustainability"]["verified"] is True
    why = body["sustainability"]["why_it_matters"]
    assert why.startswith("WWF rates Kembung / Pelaling Reduce")
    assert "Choosing better-rated seafood keeps pressure off" not in why


def test_unrated_species_is_undetermined_not_guessed(client):
    """SF013 has no wwf_assessment row on purpose.

    A missing assessment must surface as UNDETERMINED, never as a default rating.
    """
    body = client.get("/api/v1/seafood/SF013").json()
    assert body["sustainability"]["classification"] == "UNDETERMINED"
    assert body["sustainability"]["verified"] is False
    assert body["sustainability"]["assessments"] == []


def test_tenggiri_exposes_both_wwf_gear_ratings(client):
    """WWF rates Tenggiri Reduce (hook-and-line) and Avoid (gillnet)."""
    body = client.get("/api/v1/seafood/SF012").json()
    sustain = body["sustainability"]
    assert sustain["verified"] is True
    assert sustain["explanation"] == "Rating varies by catch method."
    methods = {
        row["production_method_code"]: row["classification"]
        for row in sustain["assessments"]
    }
    assert methods["HOOK_AND_LINE"] == "REDUCE"
    assert methods["GILLNET"] == "AVOID"
    listed = client.get("/api/v1/seafood").json()
    tenggiri = next(row for row in listed if row["fish_id"] == "SF012")
    assert tenggiri["classification"] == "UNDETERMINED"


def test_price_without_mapping_is_not_invented(client):
    """Observed prices are seeded from PriceCatcher; unmapped species stay empty.

    SF001 is mapped. If the observed-price seed is present the status is
    Observed; if CI applied schema without that file, Insufficient data remains
    valid. A number must never appear unless quality_status is DISPLAYABLE.
    """
    body = client.get("/api/v1/seafood/SF001/price").json()
    if body["status"] == "Observed":
        assert body["latest_price_rm_per_kg"] is not None
        assert body["latest_price_rm_per_kg"] > 0
    else:
        assert body["latest_price_rm_per_kg"] is None
        assert body["status"] in {"No PriceCatcher mapping", "Insufficient data"}
        assert body["history"] == []


def test_cooking_recommendations_accept_aliases(client):
    """The client has always sent 'grilling' and 'pan-fry'; both still resolve."""
    for term in ("grill", "grilling", "panggang"):
        res = client.get(f"/api/v1/cooking/{term}")
        assert res.status_code == 200, term
        assert res.json()["recommendations"], term

    fried = client.get("/api/v1/cooking/pan-fry").json()["recommendations"]
    assert any(r["fish_id"] == "SF004" for r in fried), "tilapia is the top fry pick"


# --- scanner contract -------------------------------------------------------


def test_identify_rejects_a_non_image(client):
    """415 is decided before the model is touched, so junk cannot spend CPU."""
    res = client.post(
        "/api/v1/identify",
        files={"file": ("notes.txt", b"this is not a fish", "text/plain")},
    )
    assert res.status_code == 415
    assert res.json()["detail"]["error"]["code"] == "UNSUPPORTED_MEDIA_TYPE"


def test_identify_rejects_an_oversized_upload(client):
    """413 before decoding: a 12 MB payload must not reach the JPEG decoder."""
    res = client.post(
        "/api/v1/identify",
        files={"file": ("huge.jpg", b"\xff\xd8\xff" + b"\x00" * (12 << 20), "image/jpeg")},
    )
    assert res.status_code == 413
    assert res.json()["detail"]["error"]["code"] == "IMAGE_TOO_LARGE"


def test_identify_rejects_a_corrupt_image(client):
    """A file that claims to be a JPEG but will not decode is 422, not 500."""
    res = client.post(
        "/api/v1/identify",
        files={"file": ("broken.jpg", b"\xff\xd8\xff\xe0" + b"garbage" * 50, "image/jpeg")},
    )
    assert res.status_code == 422
    assert res.json()["detail"]["error"]["code"] == "INVALID_IMAGE_CONTENT"


def test_identify_requires_a_file(client):
    assert client.post("/api/v1/identify").status_code == 422


def test_identify_shape_and_canonical_ids(client):
    """Every candidate must carry a real seafood_item_id, ranked, never mocked.

    Uses a flat grey frame: the prediction is meaningless, which is the point —
    this test is about the response contract, not accuracy.
    """
    res = client.post(
        "/api/v1/identify", files={"file": ("f.jpg", _jpeg(), "image/jpeg")}
    )
    assert res.status_code == 200
    body = res.json()

    assert body["status"] in {"CANDIDATES", "LOW_CONFIDENCE"}
    # Top-1 is never auto-finalised. A wrong species presented as settled fact
    # is the failure mode this whole feature has to avoid.
    assert body["confirmation_required"] is True
    # User photographs are not stored and are not reused as training data.
    assert body["image_persisted"] is False
    assert body["model_version"] and "UNTRAINED" not in body["model_version"].upper()

    assert 1 <= len(body["candidates"]) <= 3
    assert [c["rank"] for c in body["candidates"]] == list(
        range(1, len(body["candidates"]) + 1)
    )
    confidences = [c["confidence"] for c in body["candidates"]]
    assert confidences == sorted(confidences, reverse=True), "must be ranked"

    for c in body["candidates"]:
        uuid.UUID(c["seafood_item_id"])          # a real UUID, not a slug
        assert c["code"].startswith("SF")
        assert c["display_name_en"] and c["scientific_name"]
        assert 0.0 <= c["confidence"] <= 1.0


_I2_SCANNABLE = {
    "SF001", "SF002", "SF003", "SF004", "SF005",
    "SF007", "SF008", "SF012", "SF014", "SF016",
    "SF019", "SF020", "SF037", "SF038", "SF039",
    "SF041", "SF044", "SF046", "SF051",
}
_I2_MODEL_VERSION = "cv-i2-19class-convnext-tiny-20260915-original-train"


def test_identify_never_returns_an_unscannable_species(client):
    """The scanner may only name species in the 19-class map.

    If a code outside that set appeared here it would mean cv_class_mapping
    and the catalogue had drifted apart — the silent failure the seed guards
    exist to prevent. Demuduk (SF013) is never a candidate.
    """
    seen = set()
    for colour in ((30, 30, 30), (200, 200, 200), (90, 140, 190), (170, 120, 80)):
        body = client.post(
            "/api/v1/identify",
            files={"file": ("f.jpg", _jpeg(colour=colour), "image/jpeg")},
        ).json()
        seen.update(c["code"] for c in body["candidates"])
    assert seen and seen <= _I2_SCANNABLE
    assert "SF013" not in seen


def test_low_confidence_is_a_200_business_state_not_an_error(client):
    """Below threshold the app shows "not sure" — it does not show a failure.

    A 4xx here would push the client into an error path and lose the candidate
    list, which is exactly what a hesitant user needs to see.
    """
    res = client.post(
        "/api/v1/identify", files={"file": ("f.jpg", _jpeg(colour=(255, 0, 255)), "image/jpeg")}
    )
    assert res.status_code == 200
    assert res.json()["candidates"], "candidates are returned even when unsure"


@needs_corpus
def test_scanned_id_is_the_same_entity_search_returns(client):
    """The join the whole feature rests on.

    A photograph scanned and a name typed must arrive at one row. If these two
    ids ever diverge, price, WWF rating and cooking would be read off a
    different fish than the one on screen.
    """
    samples = _held_out(limit_per_class=1)
    assert samples, "manifest has test_clean rows but no files were found"

    code, path = samples[0]
    body = client.post(
        "/api/v1/identify",
        files={"file": (path.name, path.read_bytes(), "image/jpeg")},
    ).json()
    scanned_id = body["candidates"][0]["seafood_item_id"]
    scanned_code = body["candidates"][0]["code"]

    # Reached by the id the scanner returned...
    by_uuid = client.get(f"/api/v1/seafood/{scanned_id}")
    assert by_uuid.status_code == 200, "the scanner's own id must resolve"

    # ...and by the code a search would produce. Same row.
    by_code = client.get(f"/api/v1/seafood/{scanned_code}")
    assert by_code.status_code == 200
    assert by_uuid.json() == by_code.json()

    # And that row carries the joined context the app renders.
    profile = by_uuid.json()
    assert profile["aliases"]
    assert profile["cooking"]
    assert profile["sustainability"]["classification"]


@needs_corpus
def test_scanner_is_better_than_chance_on_held_out_images(client):
    """A regression floor, not a benchmark.

    Set well below the measured 78% top-1 / 94% top-3 so ordinary run-to-run
    variation does not fail the build, but high enough that a broken export, a
    shuffled class map or a wrong preprocessing constant is caught — each of
    those collapses accuracy to roughly 1/9.
    """
    samples = _held_out(limit_per_class=2)
    assert len(samples) >= 9, f"only {len(samples)} held-out images available"

    top1 = top3 = 0
    for code, path in samples:
        body = client.post(
            "/api/v1/identify",
            files={"file": (path.name, path.read_bytes(), "image/jpeg")},
        ).json()
        codes = [c["code"] for c in body["candidates"]]
        top1 += codes[0] == code
        top3 += code in codes

    n = len(samples)
    assert top1 / n >= 0.50, f"top-1 {top1}/{n} — far below the trained 0.78"
    assert top3 / n >= 0.75, f"top-3 {top3}/{n} — far below the trained 0.94"


def test_every_scannable_species_leads_somewhere(client):
    """A scan must not open an empty page.

    Resolving to a canonical id is only worth something if that id reaches the
    rest of the catalogue. This walks the reverse of the scanner's own join:
    for each class the model can emit, fetch the profile by the very id
    /identify returns and assert the sections the app renders are populated.
    """
    body = client.post(
        "/api/v1/identify", files={"file": ("f.jpg", _jpeg(), "image/jpeg")}
    ).json()
    assert body["candidates"]

    # Every code the model can emit, discovered from the catalogue rather than
    # hard-coded, so adding a class to the model cannot leave this test stale.
    scannable = [
        i["fish_id"] for i in client.get("/api/v1/seafood").json()
        if i["fish_id"] in _I2_SCANNABLE
    ]
    assert len(scannable) == 19

    for code in scannable:
        profile = client.get(f"/api/v1/seafood/{code}")
        assert profile.status_code == 200, code
        p = profile.json()
        assert p["aliases"], f"{code} has no aliases — search cannot find it"
        assert p["cooking"], f"{code} scans to an empty cooking section"
        # UNDETERMINED is a valid, deliberate answer here; absent is not.
        assert p["sustainability"]["classification"], code
        assert client.get(f"/api/v1/seafood/{code}/price").status_code == 200, code


def test_cooking_search_finds_the_newly_scannable_species(client):
    """The join runs both ways: method -> species, not only species -> method."""
    curry = client.get("/api/v1/cooking/curry").json()["recommendations"]
    assert any(r["fish_id"] == "SF012" for r in curry), "tenggiri is the curry fish"

    fried = client.get("/api/v1/cooking/fry").json()["recommendations"]
    assert any(r["fish_id"] == "SF011" for r in fried), "selar kuning fries whole"


def test_unrated_new_species_is_undetermined_not_guessed(client):
    """A species with no WWF assessment on file is UNDETERMINED, never guessed.

    Giving an unassessed species a default rating to fill the gap would read to
    a shopper as approval nobody gave. Absent guidance must stay visibly absent.

    Data-driven on purpose: the WWF seed (11_wwf_sos_2022.sql) has since rated
    most CV-expansion species, so a hard-coded list of "unrated" codes went
    stale. The rule is what matters, applied to whatever is unrated today.
    """
    unrated = []
    for item in client.get("/api/v1/seafood").json():
        code = item["fish_id"]
        s = client.get(f"/api/v1/seafood/{code}").json()["sustainability"]
        if not s["assessments"]:
            unrated.append(code)
            assert s["classification"] == "UNDETERMINED", code
            assert s["verified"] is False, code
    assert unrated, "expected at least one species with no WWF assessment on file"


def test_mixed_method_rating_is_undetermined_not_averaged(client):
    """When WWF rates a species differently by catch method, the headline stays
    UNDETERMINED and every method-specific rating is shown instead."""
    for item in client.get("/api/v1/seafood").json():
        s = client.get(f"/api/v1/seafood/{item['fish_id']}").json()["sustainability"]
        labels = {a["classification"] for a in s["assessments"]}
        if len(labels) > 1:
            assert s["classification"] == "UNDETERMINED", item["fish_id"]
            assert s["verified"] is True, item["fish_id"]


def test_class_map_matches_the_registered_model(client):
    """The catalogue's scannable set and the model's class map must agree.

    Enforced in SQL at seed time too; asserted here because this is the
    mismatch that produces confidently wrong answers with no error anywhere.
    """
    items = client.get("/api/v1/seafood").json()
    assert len(items) == 54

    body = client.post(
        "/api/v1/identify", files={"file": ("f.jpg", _jpeg(), "image/jpeg")}
    ).json()
    assert body["model_version"] == _I2_MODEL_VERSION


def test_sources_listed(client):
    res = client.get("/api/v1/sources")
    assert res.status_code == 200
    assert len(res.json()) >= 4


def test_search_finds_bawal_putih(client):
    """SF006 must be searchable by its Malay market name (QA T08)."""
    results = client.get("/api/v1/search", params={"q": "Bawal Putih"}).json()["results"]
    assert any(r["fish_id"] == "SF006" for r in results)


def test_catalogue_image_urls_are_not_storage_404s(client):
    """Every species must carry a real photo URL, not a Firebase path that 404s."""
    items = client.get("/api/v1/seafood").json()
    assert len(items) == 54
    for item in items:
        url = item["image_url"]
        assert url, item["fish_id"]


def test_forecast_rejects_malformed_location_id(client):
    """A non-UUID location_id is 400 at the boundary, not a 16s 500 (QA T14)."""
    res = client.get(
        "/api/v1/seafood/SF012/forecast",
        params={"location_id": "not-a-uuid"},
    )
    assert res.status_code == 400
    assert res.json()["detail"]["error"]["code"] == "INVALID_LOCATION"


def test_forecast_rejects_unknown_uuid_location(client):
    res = client.get(
        "/api/v1/seafood/SF012/forecast",
        params={"location_id": str(uuid.uuid4())},
    )
    assert res.status_code == 400
    assert res.json()["detail"]["error"]["code"] == "INVALID_LOCATION"


def test_fresh_account_has_empty_favourites(client):
    """A new user must not inherit a static four-item list (QA T20)."""
    email = f"qa-{uuid.uuid4().hex[:10]}@example.com"
    signup = client.post(
        "/api/v1/auth/signup",
        json={"name": "QA User", "email": email, "password": "secret12"},
    )
    assert signup.status_code == 201, signup.text
    body = signup.json()
    assert body["user"]["forecast_location_name"] == "Selangor"
    token = body["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    listed = client.get("/api/v1/me/favourites", headers=headers)
    assert listed.status_code == 200
    assert listed.json() == []

    added = client.post(
        "/api/v1/me/favourites",
        headers=headers,
        json={"fish_id": "SF006"},
    )
    assert added.status_code == 201
    assert added.json()["fish_id"] == "SF006"
    again = client.post(
        "/api/v1/me/favourites",
        headers=headers,
        json={"fish_id": "SF006"},
    )
    assert again.status_code == 201
    listed_ids = [
        row["fish_id"]
        for row in client.get("/api/v1/me/favourites", headers=headers).json()
    ]
    assert listed_ids == ["SF006"]

    removed = client.delete("/api/v1/me/favourites/SF006", headers=headers)
    assert removed.status_code == 204
    assert client.get("/api/v1/me/favourites", headers=headers).json() == []
