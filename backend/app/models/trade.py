from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, Integer, Numeric, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Trade(Base):
    __tablename__ = "trades"
    __table_args__ = (UniqueConstraint("tx_hash", "log_index", name="uq_trades_tx_log"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    wallet: Mapped[str] = mapped_column(String(42), index=True)
    market: Mapped[str] = mapped_column(String(66))
    side: Mapped[str] = mapped_column(String(8))
    size: Mapped[Decimal] = mapped_column(Numeric(36, 6))
    entry_price: Mapped[Decimal | None] = mapped_column(Numeric(36, 18), nullable=True)
    exit_price: Mapped[Decimal | None] = mapped_column(Numeric(36, 18), nullable=True)
    pnl: Mapped[Decimal | None] = mapped_column(Numeric(36, 6), nullable=True)
    leverage: Mapped[Decimal] = mapped_column(Numeric(18, 6))
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    tx_hash: Mapped[str] = mapped_column(String(66))
    log_index: Mapped[int] = mapped_column(Integer, default=0)
