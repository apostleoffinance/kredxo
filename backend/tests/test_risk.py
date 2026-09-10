import sys
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "backend"))

from fastapi.testclient import TestClient

from app.db import SessionLocal
from app.main import app
from app.risk.engine import (
    HEALTHY_TRADER,
    IDLE_ACCOUNT,
    NORMAL_MARKET,
    AccountSnapshot,
    MarketSnapshot,
    TraderSnapshot,
    current_credit,
    evaluate_risk,
    policy_payload,
    shocked_market,
)
from indexer.seed import seed_wallet

client = TestClient(app)
DEMO = "0x83000000000000000000000000000000000009A2"


def test_formula_50k_times_0_90_times_0_80():
    assert current_credit(Decimal("50000"), Decimal("0.90"), Decimal("0.80")) == Decimal("36000")


def test_explicit_multipliers_produce_elevated_policy():
    credit = current_credit(Decimal("50000"), Decimal("0.90"), Decimal("0.80"))
    elevated = evaluate_risk(
        wallet="0x1",
        base_credit=Decimal("50000"),
        trader=TraderSnapshot(
            score=87,
            max_drawdown=Decimal("0.20"),
            average_leverage=Decimal("2.0"),
            realized_pnl=Decimal("10000"),
            concentration=Decimal("0.50"),
            liquidations=0,
        ),
        market=MarketSnapshot(
            volatility=Decimal("0.45"),
            liquidity=Decimal("1.00"),
            price_move=Decimal("0"),
            correlation=Decimal("0.50"),
            funding=Decimal("0"),
        ),
    )
    assert credit == Decimal("36000")
    assert elevated.trader_multiplier == Decimal("0.90")
    assert elevated.market_multiplier == Decimal("0.80")
    assert elevated.current_credit == Decimal("36000")
    assert elevated.risk_level == "ELEVATED"
    policy = policy_payload(elevated.policy)
    assert policy == {
        "creditLimit": 36000,
        "maxLeverage": 3.5,
        "dailyLossLimit": 1500,
        "markets": {"BTC": 15000, "ETH": 10000},
        "riskLevel": "ELEVATED",
    }


def test_high_volatility_reduces_credit():
    calm = evaluate_risk("0x2", Decimal("50000"), HEALTHY_TRADER, NORMAL_MARKET)
    shocked = evaluate_risk(
        "0x2",
        Decimal("50000"),
        HEALTHY_TRADER,
        MarketSnapshot(
            volatility=Decimal("0.40"),
            liquidity=NORMAL_MARKET.liquidity,
            price_move=NORMAL_MARKET.price_move,
            correlation=NORMAL_MARKET.correlation,
            funding=NORMAL_MARKET.funding,
        ),
    )
    assert shocked.market_multiplier < calm.market_multiplier
    assert shocked.current_credit < calm.current_credit


def test_low_liquidity_reduces_credit():
    deep = evaluate_risk("0x3", Decimal("50000"), HEALTHY_TRADER, NORMAL_MARKET)
    thin = evaluate_risk(
        "0x3",
        Decimal("50000"),
        HEALTHY_TRADER,
        MarketSnapshot(
            volatility=NORMAL_MARKET.volatility,
            liquidity=Decimal("0.50"),
            price_move=NORMAL_MARKET.price_move,
            correlation=NORMAL_MARKET.correlation,
            funding=NORMAL_MARKET.funding,
        ),
    )
    assert thin.market_multiplier < deep.market_multiplier
    assert thin.current_credit < deep.current_credit


def test_higher_concentration_tightens_policy():
    diversified = evaluate_risk("0x4", Decimal("50000"), HEALTHY_TRADER, NORMAL_MARKET)
    concentrated = evaluate_risk(
        "0x4",
        Decimal("50000"),
        TraderSnapshot(
            score=HEALTHY_TRADER.score,
            max_drawdown=HEALTHY_TRADER.max_drawdown,
            average_leverage=HEALTHY_TRADER.average_leverage,
            realized_pnl=HEALTHY_TRADER.realized_pnl,
            concentration=Decimal("1.00"),
            liquidations=0,
        ),
        NORMAL_MARKET,
    )
    assert concentrated.trader_multiplier < diversified.trader_multiplier
    assert concentrated.current_credit < diversified.current_credit
    assert concentrated.policy.markets["BTC"] <= diversified.policy.markets["BTC"]
    assert concentrated.policy.max_leverage <= diversified.policy.max_leverage


def test_high_shock_tightens_leverage_and_btc():
    before = evaluate_risk("0x5", Decimal("50000"), HEALTHY_TRADER, NORMAL_MARKET, IDLE_ACCOUNT)
    after = evaluate_risk("0x5", Decimal("50000"), HEALTHY_TRADER, shocked_market(), IDLE_ACCOUNT)

    assert before.risk_level == "NORMAL"
    assert before.current_credit == Decimal("50000")
    assert before.policy.max_leverage == Decimal("5.0")
    assert before.policy.markets["BTC"] == Decimal("25000")
    assert before.policy.daily_loss_limit == Decimal("2000")

    assert after.risk_level == "HIGH"
    assert after.current_credit == Decimal("32000")
    assert after.policy.max_leverage == Decimal("3.0")
    assert after.policy.markets["BTC"] == Decimal("12000")
    assert after.policy.daily_loss_limit == Decimal("1000")
    assert after.current_credit < before.current_credit
    assert after.policy.max_leverage < before.policy.max_leverage
    assert after.policy.markets["BTC"] < before.policy.markets["BTC"]


def test_risk_states_cover_the_ladder():
    assert evaluate_risk("0x6", Decimal("50000"), HEALTHY_TRADER, NORMAL_MARKET).risk_level == "NORMAL"
    critical = evaluate_risk(
        "0x6",
        Decimal("50000"),
        TraderSnapshot(
            score=20,
            max_drawdown=Decimal("0.60"),
            average_leverage=Decimal("8"),
            realized_pnl=Decimal("-20000"),
            concentration=Decimal("1"),
            liquidations=3,
        ),
        shocked_market(),
    )
    assert critical.risk_level == "CRITICAL"


def test_account_stress_can_raise_state():
    calm = evaluate_risk("0x7", Decimal("50000"), HEALTHY_TRADER, NORMAL_MARKET, IDLE_ACCOUNT)
    stressed = evaluate_risk(
        "0x7",
        Decimal("50000"),
        HEALTHY_TRADER,
        NORMAL_MARKET,
        AccountSnapshot(
            exposure=Decimal("40000"),
            utilization=Decimal("0.90"),
            unrealized_pnl=Decimal("-4000"),
            margin=Decimal("5000"),
        ),
    )
    assert calm.risk_level == "NORMAL"
    assert stressed.account_stress >= Decimal("0.45")
    assert stressed.risk_level == "ELEVATED"


def test_empty_wallet_is_critical():
    response = client.get("/api/risk/0x0000000000000000000000000000000000000001")
    assert response.status_code == 200
    body = response.json()
    assert body["risk_level"] == "CRITICAL"
    assert Decimal(body["current_credit"]) == Decimal("0")
    assert body["policy"]["creditLimit"] == 0
    assert "trader_risk" in body
    assert "market_risk" in body
    assert "account_risk" in body


def test_api_seeded_wallet_and_shock():
    session = SessionLocal()
    seed_wallet(session, DEMO)
    session.close()

    normal = client.get(f"/api/risk/{DEMO}").json()
    assert Decimal(normal["base_credit"]) == Decimal("50000")
    assert normal["policy"]["riskLevel"] == normal["risk_level"]
    assert set(normal["policy"]["markets"]) == {"BTC", "ETH"}

    shocked = client.post(
        "/risk/evaluate",
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
    assert Decimal(shocked["current_credit"]) < Decimal(normal["current_credit"])
    assert shocked["policy"]["maxLeverage"] < normal["policy"]["maxLeverage"]
    assert shocked["policy"]["markets"]["BTC"] < normal["policy"]["markets"]["BTC"]
