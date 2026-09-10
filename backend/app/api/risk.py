from decimal import Decimal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.credit.engine import evaluate_trades
from app.db import get_session
from app.models.risk import RiskScore
from app.risk.engine import (
    AccountSnapshot,
    MarketSnapshot,
    NORMAL_MARKET,
    evaluate_from_credit,
    evaluation_payload,
)
from app.services.trades import list_trades

router = APIRouter(tags=["risk"])


class MarketBody(BaseModel):
    volatility: Decimal = Field(default=NORMAL_MARKET.volatility)
    liquidity: Decimal = Field(default=NORMAL_MARKET.liquidity)
    price_move: Decimal = Field(default=NORMAL_MARKET.price_move)
    correlation: Decimal = Field(default=NORMAL_MARKET.correlation)
    funding: Decimal = Field(default=NORMAL_MARKET.funding)


class AccountBody(BaseModel):
    exposure: Decimal = Decimal("0")
    utilization: Decimal = Decimal("0")
    unrealized_pnl: Decimal = Decimal("0")
    margin: Decimal = Decimal("0")


class EvaluateRequest(BaseModel):
    wallet: str
    market: MarketBody | None = None
    account: AccountBody | None = None


def _market(body: MarketBody | None) -> MarketSnapshot:
    if body is None:
        return NORMAL_MARKET
    return MarketSnapshot(
        volatility=body.volatility,
        liquidity=body.liquidity,
        price_move=body.price_move,
        correlation=body.correlation,
        funding=body.funding,
    )


def _account(body: AccountBody | None) -> AccountSnapshot:
    if body is None:
        return AccountSnapshot(
            exposure=Decimal("0"),
            utilization=Decimal("0"),
            unrealized_pnl=Decimal("0"),
            margin=Decimal("0"),
        )
    return AccountSnapshot(
        exposure=body.exposure,
        utilization=body.utilization,
        unrealized_pnl=body.unrealized_pnl,
        margin=body.margin,
    )


def _evaluate(
    session: Session,
    wallet: str,
    market: MarketSnapshot,
    account: AccountSnapshot,
) -> dict:
    trades = list(list_trades(session, wallet))
    credit = evaluate_trades(wallet, trades)
    result = evaluate_from_credit(credit, market=market, account=account)
    session.add(
        RiskScore(
            wallet=result.wallet,
            risk_level=result.risk_level,
            current_credit=result.current_credit,
            trader_multiplier=result.trader_multiplier,
            market_multiplier=result.market_multiplier,
            max_leverage=result.policy.max_leverage,
            daily_loss_limit=result.policy.daily_loss_limit,
        )
    )
    session.commit()
    return evaluation_payload(result)


@router.get("/api/risk/{wallet}")
def get_risk(wallet: str, session: Session = Depends(get_session)) -> dict:
    return _evaluate(session, wallet, NORMAL_MARKET, _account(None))


@router.post("/risk/evaluate")
def post_risk(body: EvaluateRequest, session: Session = Depends(get_session)) -> dict:
    return _evaluate(session, body.wallet, _market(body.market), _account(body.account))
