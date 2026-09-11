import sys
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "backend"))

from fastapi.testclient import TestClient

from app.credit.engine import evaluate_trades
from app.db import SessionLocal
from app.main import app
from app.services.trades import list_trades
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


def test_demo_trader_is_advanced_87_with_fifty_k():
    session = SessionLocal()
    seed_wallet(session, DEMO)
    session.close()

    credit = client.get(f"/api/credit/{DEMO}").json()
    trades = client.get(f"/api/trades/{DEMO}").json()
    assert credit["score"] == 87
    assert credit["tier"] == "ADVANCED"
    assert Decimal(credit["base_credit"]) == Decimal("50000")
    assert int(credit["metrics"]["liquidations"]) == 0
    assert int(credit["metrics"]["trade_count"]) == 120
    assert Decimal(trades["volume"]) > Decimal("1600000")
    assert Decimal(trades["volume"]) < Decimal("2200000")
    assert Decimal(trades["realized_pnl"]) == Decimal("83420")
    assert Decimal(credit["metrics"]["max_drawdown"]) < Decimal("0.12")
    assert Decimal(credit["metrics"]["max_drawdown"]) > Decimal("0.05")

    session = SessionLocal()
    evaluated = evaluate_trades(DEMO, list(list_trades(session, DEMO)))
    session.close()
    assert evaluated.score == 87
    assert evaluated.metrics.liquidations == 0
