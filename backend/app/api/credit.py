from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.risk import AccountBody, MarketBody
from app.credit.engine import evaluate_trades, evaluation_payload
from app.db import get_session
from app.models.credit import CreditScore
from app.services.lifecycle import request_credit
from app.services.trades import list_trades

router = APIRouter(tags=["credit"])


class EvaluateRequest(BaseModel):
    wallet: str


class RequestCreditBody(BaseModel):
    wallet: str
    market: MarketBody | None = None
    account: AccountBody | None = None


def _evaluate(session: Session, wallet: str) -> dict:
    trades = list(list_trades(session, wallet))
    result = evaluate_trades(wallet, trades)
    session.add(
        CreditScore(
            wallet=result.wallet,
            score=result.score,
            tier=result.tier,
            base_credit=result.base_credit,
        )
    )
    session.commit()
    return evaluation_payload(result)


@router.get("/api/credit/{wallet}")
def get_credit(wallet: str, session: Session = Depends(get_session)) -> dict:
    return _evaluate(session, wallet)


@router.post("/credit/evaluate")
def post_credit(body: EvaluateRequest, session: Session = Depends(get_session)) -> dict:
    return _evaluate(session, body.wallet)


@router.post("/credit/request")
def post_credit_request(body: RequestCreditBody, session: Session = Depends(get_session)) -> dict:
    return request_credit(session, body.wallet, market=body.market, account=body.account)
