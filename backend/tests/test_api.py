"""API contract tests against a real PostgreSQL database."""


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
    assert body["seafood_count"] == 5


def test_list_seafood(client):
    res = client.get("/api/v1/seafood")
    assert res.status_code == 200
    items = res.json()
    assert len(items) == 5
    assert {i["fish_id"] for i in items} == {"SF001", "SF002", "SF003", "SF004", "SF005"}


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


def test_unknown_species_is_404(client):
    assert client.get("/api/v1/seafood/SF999").status_code == 404


def test_rated_species_reports_its_wwf_rating(client):
    body = client.get("/api/v1/seafood/SF001").json()
    assert body["sustainability"]["classification"] == "GOOD CHOICE"
    assert body["sustainability"]["verified"] is True


def test_unrated_species_is_undetermined_not_guessed(client):
    """SF005 has no wwf_assessment row on purpose.

    This is the single most important behaviour in the sustainability epic:
    a missing assessment must surface as UNDETERMINED, never as a default
    rating that a shopper would read as approval.
    """
    body = client.get("/api/v1/seafood/SF005").json()
    assert body["sustainability"]["classification"] == "UNDETERMINED"
    assert body["sustainability"]["verified"] is False


def test_price_without_mapping_is_not_invented(client):
    """No PriceCatcher mapping is loaded yet, so no price may be reported."""
    body = client.get("/api/v1/seafood/SF001/price").json()
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


def test_identify_returns_a_cv_supported_species(client):
    body = client.post("/api/v1/identify").json()
    assert body["is_mock"] is True
    assert body["requires_user_confirmation"] is True
    assert body["top_prediction"]["fish_id"].startswith("SF")


def test_sources_listed(client):
    res = client.get("/api/v1/sources")
    assert res.status_code == 200
    assert len(res.json()) >= 4
