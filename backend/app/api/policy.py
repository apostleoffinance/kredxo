from time import time

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.risk import AccountBody, MarketBody, _account, _market
from app.credit.engine import evaluate_trades
from app.db import get_session
from app.policy.encode import DEFAULT_VALIDITY_SECONDS, onchain_policy
from app.risk.engine import evaluate_from_credit, policy_payload
from app.services.trades import list_trades

router = APIRouter(tags=["policy"])


class ProposeRequest(BaseModel):
    wallet: str
    market: MarketBody | None = None
    account: AccountBody | None = None
    valid_for: int = Field(default=DEFAULT_VALIDITY_SECONDS, ge=1)


def _propose(
    session: Session,
    wallet: str,
    market: MarketBody | None,
    account: AccountBody | None,
    valid_for: int,
) -> dict:
    trades = list(list_trades(session, wallet))
    credit = evaluate_trades(wallet, trades)
    risk = evaluate_from_credit(credit, market=_market(market), account=_account(account))
    now = int(time())
    return {
        "wallet": risk.wallet,
        "risk_level": risk.risk_level,
        "policy": policy_payload(risk.policy),
        "onchain": onchain_policy(risk.policy, now, now + valid_for),
    }


@router.get("/api/policy/{wallet}")
def get_policy(wallet: str, session: Session = Depends(get_session)) -> dict:
    return _propose(session, wallet, None, None, DEFAULT_VALIDITY_SECONDS)


@router.post("/policy/propose")
def post_policy(body: ProposeRequest, session: Session = Depends(get_session)) -> dict:
    return _propose(session, body.wallet, body.market, body.account, body.valid_for)
