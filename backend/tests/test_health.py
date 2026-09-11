from fastapi.testclient import TestClient

from app.main import CORS_ORIGINS, app

client = TestClient(app)


def test_health_shape():
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["phase"] == 19
    assert body["monad"]["configured_chain_id"] == 10143
    assert body["monad"]["rpc_url"].startswith("http")


def test_credit_request_preflight_allows_local_frontends():
    for origin in CORS_ORIGINS:
        response = client.options(
            "/credit/request",
            headers={
                "Origin": origin,
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "content-type",
            },
        )
        assert response.status_code == 200, origin
        assert response.headers["access-control-allow-origin"] == origin


def test_credit_request_preflight_rejects_other_origins():
    response = client.options(
        "/credit/request",
        headers={
            "Origin": "http://192.168.1.10:3000",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type",
        },
    )
    assert response.status_code == 400
    assert "access-control-allow-origin" not in response.headers
