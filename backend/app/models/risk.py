from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class RiskScore(Base):
    __tablename__ = "risk_scores"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    wallet: Mapped[str] = mapped_column(String(42), index=True)
    risk_level: Mapped[str] = mapped_column(String(16))
    current_credit: Mapped[Decimal] = mapped_column(Numeric(36, 6))
    trader_multiplier: Mapped[Decimal] = mapped_column(Numeric(18, 6))
    market_multiplier: Mapped[Decimal] = mapped_column(Numeric(18, 6))
    max_leverage: Mapped[Decimal] = mapped_column(Numeric(18, 6))
    daily_loss_limit: Mapped[Decimal] = mapped_column(Numeric(36, 6))
    computed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
