from __future__ import annotations

import json
from decimal import Decimal
from pathlib import Path
from time import time

from sqlalchemy.orm import Session

from app.credit.engine import evaluate_trades
from app.policy.encode import DEFAULT_VALIDITY_SECONDS, USDC_DECIMALS, onchain_policy
from app.risk.engine import (
    NORMAL_MARKET,
    evaluate_from_credit,
    evaluation_payload,
    policy_payload,
    recovering_market,
    shocked_market,
)
from app.services.lifecycle import TRADE_SIZE_USDC, _flatten_onchain
from app.services.trades import list_trades

TRADE = {"market": "BTC", "size": TRADE_SIZE_USDC, "leverage": 2}


def _stage(name: str, risk, valid_for: int) -> dict:
    now = int(time())
    onchain = onchain_policy(risk.policy, now, now + valid_for)
    return {
        "name": name,
        "risk_level": risk.risk_level,
        "current_credit": format(risk.current_credit, "f"),
        "trader_multiplier": format(risk.trader_multiplier, "f"),
        "market_multiplier": format(risk.market_multiplier, "f"),
        "market_risk": {
            "volatility": format(risk.market.volatility, "f"),
            "liquidity": format(risk.market.liquidity, "f"),
            "price_move": format(risk.market.price_move, "f"),
            "correlation": format(risk.market.correlation, "f"),
            "funding": format(risk.market.funding, "f"),
        },
        "policy": policy_payload(risk.policy),
        "onchain": onchain,
        "onchain_flat": _flatten_onchain(onchain),
        "risk": evaluation_payload(risk),
    }


def _allows(stage: dict, size: int, leverage: float) -> bool:
    policy = stage["policy"]
    return (
        size <= policy["markets"].get("BTC", 0)
        and leverage <= policy["maxLeverage"]
        and size > 0
    )


def simulate_stress(session: Session, wallet: str, valid_for: int = DEFAULT_VALIDITY_SECONDS) -> dict:
    trades = list(list_trades(session, wallet))
    credit = evaluate_trades(wallet, trades)
    before = evaluate_from_credit(credit, market=NORMAL_MARKET)
    high = evaluate_from_credit(credit, market=shocked_market())
    elevated = evaluate_from_credit(credit, market=recovering_market())
    restored = evaluate_from_credit(credit, market=NORMAL_MARKET)

    stages = {
        "normal": _stage("normal", before, valid_for),
        "shock": _stage("shock", high, valid_for),
        "elevated": _stage("elevated", elevated, valid_for),
        "recovered": _stage("recovered", restored, valid_for),
    }
    size = TRADE["size"]
    lev = TRADE["leverage"]
    return {
        "wallet": wallet.lower(),
        "score": credit.score,
        "tier": credit.tier,
        "base_credit": format(credit.base_credit, "f"),
        "injection": {
            "volatility": "+85%",
            "liquidity": "-28%",
            "price_move": "-12%",
            "correlation": "+20%",
        },
        "stages": stages,
        "trade": {
            **TRADE,
            "allowed_before": _allows(stages["normal"], size, lev),
            "allowed_after_shock": _allows(stages["shock"], size, lev),
            "allowed_after_elevated": _allows(stages["elevated"], size, lev),
            "allowed_after_recovery": _allows(stages["recovered"], size, lev),
        },
    }


def write_stress_fixture(path: Path, sitting: dict) -> dict:
    stages = sitting["stages"]
    payload = {
        "score": sitting["score"],
        "tier": sitting["tier"],
        "baseCredit": int(Decimal(sitting["base_credit"]) * USDC_DECIMALS),
        "tradeSize": int(Decimal(TRADE_SIZE_USDC) * USDC_DECIMALS),
        "leverage": 2 * 10**18,
        "normal": stages["normal"]["onchain_flat"],
        "shock": stages["shock"]["onchain_flat"],
        "elevated": stages["elevated"]["onchain_flat"],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n")
    return payload
