"""Smoke tests for health and seeded seafood listing."""

from fastapi.testclient import TestClient

from app.main import app


def test_health():
    with TestClient(app) as client:
        res = client.get("/api/v1/health")
        assert res.status_code == 200
        assert res.json()["status"] == "ok"


def test_list_seafood():
    with TestClient(app) as client:
        res = client.get("/api/v1/seafood")
        assert res.status_code == 200
        assert len(res.json()) == 5


def test_search_kembung():
    with TestClient(app) as client:
        res = client.get("/api/v1/search", params={"q": "kembung"})
        assert res.status_code == 200
        results = res.json()["results"]
        assert any(r["fish_id"] == "fish_kembung" for r in results)
