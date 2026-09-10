from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db import get_session
from app.services.stress import simulate_stress

router = APIRouter(tags=["stress"])


class StressRequest(BaseModel):
    wallet: str


@router.post("/stress/simulate")
def post_stress(body: StressRequest, session: Session = Depends(get_session)) -> dict:
    return simulate_stress(session, body.wallet)
