from datetime import UTC, datetime
from decimal import Decimal

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.db import SessionLocal
from app.main import app
from app.services.trades import upsert_trade

client = TestClient(app)

DEMO = "0x83000000000000000000000000000000000009A2"


def test_trades_empty_wallet():
    response = client.get(f"/api/trades/{DEMO}")
    assert response.status_code == 200
    body = response.json()
    assert body["wallet"] == DEMO.lower()
    assert body["count"] == 0
    assert body["trades"] == []


def test_trades_round_trip():
    session: Session = SessionLocal()
    upsert_trade(
        session,
        wallet=DEMO,
        market="0xB7C0000000000000000000000000000000000001",
        side="LONG",
        size=Decimal("10000"),
        leverage=Decimal("3"),
        timestamp=datetime(2025, 6, 1, tzinfo=UTC),
        tx_hash="0x" + "ab" * 32,
        entry_price=Decimal("60000"),
        exit_price=Decimal("61200"),
        pnl=Decimal("200"),
    )
    session.commit()
    session.close()

    response = client.get(f"/api/trades/{DEMO}")
    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 1
    assert body["volume"].startswith("10000")
    assert body["realized_pnl"].startswith("200")
    assert body["trades"][0]["side"] == "LONG"
    assert body["trades"][0]["tx_hash"].startswith("0x")
