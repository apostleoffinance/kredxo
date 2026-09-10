from __future__ import annotations

import json
from decimal import Decimal
from pathlib import Path
from time import time

from sqlalchemy.orm import Session

from app.api.risk import AccountBody, MarketBody, _account, _market
from app.credit.engine import evaluate_trades
from app.models.credit import CreditScore
from app.models.risk import RiskScore
from app.policy.encode import DEFAULT_VALIDITY_SECONDS, USDC_DECIMALS, onchain_policy
from app.risk.engine import evaluate_from_credit, evaluation_payload, policy_payload
from app.services.trades import list_trades

TRADE_SIZE_USDC = 20_000
LEVERAGE_X = 2


def request_credit(
    session: Session,
    wallet: str,
    market: MarketBody | None = None,
    account: AccountBody | None = None,
    valid_for: int = DEFAULT_VALIDITY_SECONDS,
) -> dict:
    trades = list(list_trades(session, wallet))
    credit = evaluate_trades(wallet, trades)
    risk = evaluate_from_credit(credit, market=_market(market), account=_account(account))
    session.add(
        CreditScore(
            wallet=credit.wallet,
            score=credit.score,
            tier=credit.tier,
            base_credit=credit.base_credit,
        )
    )
    session.add(
        RiskScore(
            wallet=risk.wallet,
            risk_level=risk.risk_level,
            current_credit=risk.current_credit,
            trader_multiplier=risk.trader_multiplier,
            market_multiplier=risk.market_multiplier,
            max_leverage=risk.policy.max_leverage,
            daily_loss_limit=risk.policy.daily_loss_limit,
        )
    )
    session.commit()

    now = int(time())
    onchain = onchain_policy(risk.policy, now, now + valid_for)
    return {
        "wallet": credit.wallet,
        "score": credit.score,
        "tier": credit.tier,
        "base_credit": format(credit.base_credit, "f"),
        "current_credit": format(risk.current_credit, "f"),
        "risk": evaluation_payload(risk),
        "policy": policy_payload(risk.policy),
        "onchain": onchain,
        "onchain_flat": _flatten_onchain(onchain),
    }


def _flatten_onchain(onchain: dict) -> dict:
    markets = {row["symbol"]: row["limit"] for row in onchain["markets"]}
    return {
        "creditLimit": onchain["creditLimit"],
        "maxLeverage": onchain["maxLeverage"],
        "dailyLossLimit": onchain["dailyLossLimit"],
        "riskLevel": onchain["riskLevel"],
        "btcLimit": markets.get("BTC", 0),
        "ethLimit": markets.get("ETH", 0),
    }


def lifecycle_fixture(normal: dict, shock: dict) -> dict:
    trade_size = int(Decimal(TRADE_SIZE_USDC) * USDC_DECIMALS)
    return {
        "score": normal["score"],
        "tier": normal["tier"],
        "baseCredit": int(Decimal(normal["base_credit"]) * USDC_DECIMALS),
        "tradeSize": trade_size,
        "leverage": LEVERAGE_X * 10**18,
        "normal": normal["onchain_flat"],
        "shock": shock["onchain_flat"],
    }


def write_lifecycle_fixture(path: Path, normal: dict, shock: dict) -> dict:
    payload = lifecycle_fixture(normal, shock)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n")
    return payload
