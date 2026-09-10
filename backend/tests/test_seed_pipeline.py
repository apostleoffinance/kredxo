import sys
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "backend"))

from fastapi.testclient import TestClient

from app.db import SessionLocal
from app.main import app
from indexer.seed import TARGET_PNL, TRADE_COUNT, build_demo_trades, seed_wallet

DEMO = "0x83000000000000000000000000000000000009A2"
client = TestClient(app)


def test_demo_seed_hits_target_pnl():
    rows = build_demo_trades(DEMO)
    assert len(rows) == TRADE_COUNT
    pnl = sum((row["pnl"] for row in rows), Decimal("0"))
    assert pnl == TARGET_PNL
    assert all(row["tx_hash"].startswith("0x") for row in rows)


def test_seeded_wallet_is_readable_via_api():
    session = SessionLocal()
    seed_wallet(session, DEMO)
    session.close()

    response = client.get(f"/api/trades/{DEMO}")
    assert response.status_code == 200
    body = response.json()
    assert body["count"] == TRADE_COUNT
    assert Decimal(body["realized_pnl"]) == TARGET_PNL
    assert Decimal(body["volume"]) > 0
    assert body["trades"][0]["wallet"] == DEMO.lower()
