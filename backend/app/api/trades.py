from decimal import Decimal

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_session
from app.services.trades import list_trades

router = APIRouter(prefix="/api/trades", tags=["trades"])


def _num(value: Decimal | None) -> str | None:
    if value is None:
        return None
    return format(value, "f")


@router.get("/{wallet}")
def get_trades(wallet: str, session: Session = Depends(get_session)) -> dict:
    trades = list_trades(session, wallet)
    volume = sum((t.size for t in trades), Decimal("0"))
    pnl = sum((t.pnl or Decimal("0") for t in trades), Decimal("0"))
    return {
        "wallet": wallet.lower(),
        "count": len(trades),
        "volume": _num(volume),
        "realized_pnl": _num(pnl),
        "trades": [
            {
                "id": t.id,
                "wallet": t.wallet,
                "market": t.market,
                "side": t.side,
                "size": _num(t.size),
                "entry_price": _num(t.entry_price),
                "exit_price": _num(t.exit_price),
                "pnl": _num(t.pnl),
                "leverage": _num(t.leverage),
                "timestamp": t.timestamp.isoformat(),
                "tx_hash": t.tx_hash,
            }
            for t in trades
        ],
    }
