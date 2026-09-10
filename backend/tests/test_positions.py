from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_positions_are_live_empty_until_indexed():
    body = client.get("/api/positions/0x83000000000000000000000000000000000009A2").json()
    assert body["wallet"] == "0x83000000000000000000000000000000000009a2"
    assert body["positions"] == []
