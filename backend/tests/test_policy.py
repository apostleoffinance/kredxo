import sys
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "backend"))

from fastapi.testclient import TestClient

from app.db import SessionLocal
from app.main import app
from app.policy.encode import LEVELS, onchain_policy
from app.risk.engine import RiskPolicy
from indexer.seed import seed_wallet

client = TestClient(app)
DEMO = "0x83000000000000000000000000000000000009A2"


def test_onchain_encoding_matches_usdc_and_wad():
    policy = RiskPolicy(
        credit_limit=Decimal("32000"),
        max_leverage=Decimal("3.0"),
        daily_loss_limit=Decimal("1000"),
        markets={"BTC": Decimal("12000"), "ETH": Decimal("8000")},
        risk_level="HIGH",
    )
    encoded = onchain_policy(policy, valid_from=100, valid_until=200)
    assert encoded["creditLimit"] == 32_000 * 1_000_000
    assert encoded["maxLeverage"] == 3 * 10**18
    assert encoded["dailyLossLimit"] == 1_000 * 1_000_000
    assert encoded["riskLevel"] == LEVELS["HIGH"]
    assert encoded["markets"][0] == {"symbol": "BTC", "limit": 12_000 * 1_000_000}


def test_empty_wallet_policy_is_critical_zero():
    body = client.get("/api/policy/0x0000000000000000000000000000000000000001").json()
    assert body["risk_level"] == "CRITICAL"
    assert body["policy"]["creditLimit"] == 0
    assert body["onchain"]["creditLimit"] == 0
    assert body["onchain"]["riskLevel"] == LEVELS["CRITICAL"]
    assert body["onchain"]["validUntil"] > body["onchain"]["validFrom"]


def test_propose_shock_tightens_onchain_limits():
    session = SessionLocal()
    seed_wallet(session, DEMO)
    session.close()

    normal = client.get(f"/api/policy/{DEMO}").json()
    shocked = client.post(
        "/policy/propose",
        json={
            "wallet": DEMO,
            "market": {
                "volatility": 0.37,
                "liquidity": 0.72,
                "price_move": 0.12,
                "correlation": 0.70,
                "funding": 0,
            },
        },
    ).json()

    assert normal["onchain"]["creditLimit"] == normal["policy"]["creditLimit"] * 1_000_000
    assert shocked["policy"]["creditLimit"] < normal["policy"]["creditLimit"]
    assert shocked["onchain"]["maxLeverage"] < normal["onchain"]["maxLeverage"]
    btc_normal = next(m["limit"] for m in normal["onchain"]["markets"] if m["symbol"] == "BTC")
    btc_shock = next(m["limit"] for m in shocked["onchain"]["markets"] if m["symbol"] == "BTC")
    assert btc_shock < btc_normal
    assert shocked["onchain"]["riskLevel"] > normal["onchain"]["riskLevel"]
