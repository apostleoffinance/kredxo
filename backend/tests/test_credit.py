import sys
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "backend"))


from fastapi.testclient import TestClient

from app.credit.engine import evaluate_trades
from app.db import SessionLocal
from app.main import app
from indexer.seed import seed_wallet

client = TestClient(app)
DEMO = "0x83000000000000000000000000000000000009A2"


def _trade(pnl: str, size: str = "10000", leverage: str = "2", market: str = "BTC") -> SimpleNamespace:
    return SimpleNamespace(
        pnl=Decimal(pnl),
        size=Decimal(size),
        leverage=Decimal(leverage),
        market=market,
        timestamp=datetime(2025, 6, 1, tzinfo=UTC),
    )


def test_empty_wallet_is_restricted():
    response = client.get("/api/credit/0x0000000000000000000000000000000000000001")
    assert response.status_code == 200
    body = response.json()
    assert body["score"] == 0
    assert body["tier"] == "RESTRICTED"
    assert Decimal(body["base_credit"]) == Decimal("0")


def test_seeded_wallet_is_advanced_87():
    session = SessionLocal()
    seed_wallet(session, DEMO)
    session.close()

    response = client.get(f"/api/credit/{DEMO}")
    assert response.status_code == 200
    body = response.json()
    assert body["score"] == 87
    assert body["tier"] == "ADVANCED"
    assert Decimal(body["base_credit"]) == Decimal("50000")
    assert int(body["metrics"]["liquidations"]) == 0
    assert int(body["metrics"]["trade_count"]) == 120


def test_high_sharpe_increases_score():
    steady = [_trade("80") for _ in range(20)]
    noisy = [_trade("400") if i % 2 == 0 else _trade("-240") for i in range(20)]
    high = evaluate_trades("0x1", steady)
    low = evaluate_trades("0x2", noisy)
    assert high.metrics.sharpe > low.metrics.sharpe
    assert high.score > low.score


def test_high_drawdown_decreases_score():
    flat = [_trade("50") for _ in range(12)]
    crashed = [_trade("50") for _ in range(6)] + [_trade("-8000")] + [_trade("50") for _ in range(5)]
    stable = evaluate_trades("0x3", flat)
    drawn = evaluate_trades("0x4", crashed)
    assert drawn.metrics.max_drawdown > stable.metrics.max_drawdown
    assert drawn.score < stable.score


def test_liquidation_decreases_score():
    clean = [_trade("100", size="10000", leverage="2") for _ in range(8)]
    blown = list(clean)
    blown[0] = _trade("-6000", size="10000", leverage="2")
    good = evaluate_trades("0x5", clean)
    bad = evaluate_trades("0x6", blown)
    assert good.metrics.liquidations == 0
    assert bad.metrics.liquidations >= 1
    assert bad.score < good.score


def test_post_evaluate_matches_get():
    session = SessionLocal()
    seed_wallet(session, DEMO)
    session.close()
    posted = client.post("/credit/evaluate", json={"wallet": DEMO}).json()
    assert posted["score"] == 87
    assert posted["tier"] == "ADVANCED"
