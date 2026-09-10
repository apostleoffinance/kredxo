from collections.abc import Sequence
from datetime import datetime
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.trade import Trade


def upsert_trade(
    session: Session,
    *,
    wallet: str,
    market: str,
    side: str,
    size: Decimal,
    leverage: Decimal,
    timestamp: datetime,
    tx_hash: str,
    log_index: int = 0,
    entry_price: Decimal | None = None,
    exit_price: Decimal | None = None,
    pnl: Decimal | None = None,
) -> Trade:
    existing = session.scalar(
        select(Trade).where(Trade.tx_hash == tx_hash, Trade.log_index == log_index)
    )
    if existing:
        existing.wallet = wallet.lower()
        existing.market = market
        existing.side = side
        existing.size = size
        existing.leverage = leverage
        existing.timestamp = timestamp
        existing.entry_price = entry_price
        existing.exit_price = exit_price
        existing.pnl = pnl
        return existing

    trade = Trade(
        wallet=wallet.lower(),
        market=market,
        side=side,
        size=size,
        leverage=leverage,
        timestamp=timestamp,
        tx_hash=tx_hash,
        log_index=log_index,
        entry_price=entry_price,
        exit_price=exit_price,
        pnl=pnl,
    )
    session.add(trade)
    return trade


def list_trades(session: Session, wallet: str) -> Sequence[Trade]:
    return session.scalars(
        select(Trade)
        .where(Trade.wallet == wallet.lower())
        .order_by(Trade.timestamp.asc(), Trade.id.asc())
    ).all()
