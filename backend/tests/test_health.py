from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_shape():
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["phase"] == 13
    assert body["monad"]["configured_chain_id"] == 10143
    assert body["monad"]["rpc_url"].startswith("http")
