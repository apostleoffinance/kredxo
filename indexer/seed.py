from __future__ import annotations

import hashlib
import random
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy.orm import Session

from app.services.trades import upsert_trade

BTC = "0xB7C0000000000000000000000000000000000001"
ETH = "0xE700000000000000000000000000000000000001"
TARGET_PNL = Decimal("83420")
STARTING_EQUITY = Decimal("100000")
TRADE_COUNT = 120


def _tx_hash(wallet: str, index: int) -> str:
    digest = hashlib.sha256(f"{wallet}:{index}:kredxo-phase5".encode()).hexdigest()
    return "0x" + digest


def build_demo_trades(wallet: str) -> list[dict]:
    """120 trades, +$83,420 PnL, ~$1.82M volume, no liquidations."""
    rng = random.Random(87)
    start = datetime(2025, 3, 1, tzinfo=UTC)
    target_equity = STARTING_EQUITY + TARGET_PNL

    steps = [Decimal(str(rng.gauss(0.006, 0.03))) for _ in range(TRADE_COUNT)]
    path = [STARTING_EQUITY]
    equity = STARTING_EQUITY
    for step in steps:
        equity = equity * (Decimal("1") + step)
        path.append(equity)

    raw_end = path[-1]
    scale = (target_equity - STARTING_EQUITY) / (raw_end - STARTING_EQUITY)
    scaled = [STARTING_EQUITY + (point - STARTING_EQUITY) * scale for point in path]
    pnls = [scaled[i + 1] - scaled[i] for i in range(TRADE_COUNT)]

    trades: list[dict] = []
    for i, pnl in enumerate(pnls):
        market = BTC if i % 3 else ETH
        side = "LONG" if pnl >= 0 else "SHORT"
        leverage = Decimal(str(round(rng.uniform(1.4, 2.8), 2)))
        size = Decimal(str(round(rng.uniform(12_000, 18_500), 2)))
        if pnl < 0:
            min_size = (-pnl) * leverage / Decimal("0.80")
            if size < min_size:
                size = min_size.quantize(Decimal("0.01"))
        entry = Decimal("60000") if market == BTC else Decimal("3200")
        move = (pnl / size) if size else Decimal("0")
        if side == "SHORT":
            move = -move
        exit_price = (entry * (Decimal("1") + move)).quantize(Decimal("0.01"))
        trades.append(
            {
                "wallet": wallet,
                "market": market,
                "side": side,
                "size": size,
                "leverage": leverage,
                "entry_price": entry,
                "exit_price": exit_price,
                "pnl": pnl.quantize(Decimal("0.01")),
                "timestamp": start + timedelta(hours=18 * i),
                "tx_hash": _tx_hash(wallet, i),
                "log_index": 0,
            }
        )
    drift = TARGET_PNL - sum((row["pnl"] for row in trades), Decimal("0"))
    trades[-1]["pnl"] = (trades[-1]["pnl"] + drift).quantize(Decimal("0.01"))
    return trades


def seed_wallet(session: Session, wallet: str) -> int:
    rows = build_demo_trades(wallet)
    for row in rows:
        upsert_trade(session, **row)
    session.commit()
    return len(rows)
