from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from decimal import Decimal
from statistics import mean, pstdev

from app.models.trade import Trade

STARTING_EQUITY = Decimal("100000")


@dataclass(frozen=True)
class CreditMetrics:
    trade_count: int
    volume: Decimal
    realized_pnl: Decimal
    return_on_equity: Decimal
    win_rate: Decimal
    sharpe: Decimal
    sortino: Decimal
    max_drawdown: Decimal
    average_leverage: Decimal
    liquidations: int
    concentration: Decimal
    consistency: Decimal


def _dec(value: float) -> Decimal:
    return Decimal(str(round(value, 6)))


def compute_metrics(trades: Sequence[Trade], starting_equity: Decimal = STARTING_EQUITY) -> CreditMetrics:
    if not trades:
        return CreditMetrics(
            trade_count=0,
            volume=Decimal("0"),
            realized_pnl=Decimal("0"),
            return_on_equity=Decimal("0"),
            win_rate=Decimal("0"),
            sharpe=Decimal("0"),
            sortino=Decimal("0"),
            max_drawdown=Decimal("0"),
            average_leverage=Decimal("0"),
            liquidations=0,
            concentration=Decimal("0"),
            consistency=Decimal("0"),
        )

    pnls = [Decimal(t.pnl or 0) for t in trades]
    sizes = [Decimal(t.size) for t in trades]
    leverages = [Decimal(t.leverage) for t in trades]
    volume = sum(sizes, Decimal("0"))
    realized = sum(pnls, Decimal("0"))
    wins = sum(1 for p in pnls if p > 0)
    win_rate = Decimal(wins) / Decimal(len(trades))

    equity = starting_equity
    peak = equity
    max_dd = Decimal("0")
    equity_returns: list[float] = []
    for pnl in pnls:
        ret = float(pnl / equity) if equity > 0 else 0.0
        equity_returns.append(ret)
        equity += pnl
        if equity > peak:
            peak = equity
        drawdown = (peak - equity) / peak if peak > 0 else Decimal("0")
        if drawdown > max_dd:
            max_dd = drawdown

    avg_r = mean(equity_returns)
    std_r = pstdev(equity_returns) if len(equity_returns) > 1 else 0.0
    downside = [r for r in equity_returns if r < 0]
    down_std = pstdev(downside) if len(downside) > 1 else 0.0
    scale = len(equity_returns) ** 0.5
    sharpe = (avg_r / std_r) * scale if std_r else 0.0
    sortino = (avg_r / down_std) * scale if down_std else 0.0

    liquidations = 0
    for trade, pnl in zip(trades, pnls, strict=True):
        leverage = Decimal(trade.leverage) or Decimal("1")
        margin = Decimal(trade.size) / leverage
        if margin > 0 and pnl <= -margin:
            liquidations += 1

    markets: dict[str, Decimal] = {}
    for trade, size in zip(trades, sizes, strict=True):
        markets[trade.market] = markets.get(trade.market, Decimal("0")) + size
    concentration = (
        sum((share / volume) ** 2 for share in markets.values()) if volume else Decimal("1")
    )

    half = len(pnls) // 2 or 1
    first_wr = sum(1 for p in pnls[:half] if p > 0) / len(pnls[:half])
    second_wr = sum(1 for p in pnls[half:] if p > 0) / len(pnls[half:])
    consistency = Decimal("1") - Decimal(str(abs(first_wr - second_wr)))

    return CreditMetrics(
        trade_count=len(trades),
        volume=volume,
        realized_pnl=realized,
        return_on_equity=(realized / starting_equity) if starting_equity else Decimal("0"),
        win_rate=win_rate,
        sharpe=_dec(sharpe),
        sortino=_dec(sortino),
        max_drawdown=max_dd,
        average_leverage=(sum(leverages, Decimal("0")) / Decimal(len(leverages))),
        liquidations=liquidations,
        concentration=concentration,
        consistency=consistency,
    )
