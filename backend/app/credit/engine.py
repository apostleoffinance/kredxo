from __future__ import annotations

from dataclasses import asdict, dataclass
from decimal import Decimal

from app.credit.metrics import CreditMetrics, compute_metrics
from app.models.trade import Trade

WEIGHTS = {
    "performance": Decimal("0.25"),
    "risk_adjusted": Decimal("0.20"),
    "drawdown": Decimal("0.20"),
    "leverage": Decimal("0.15"),
    "liquidations": Decimal("0.10"),
    "consistency": Decimal("0.10"),
}

TIERS = (
    (39, "RESTRICTED", Decimal("0")),
    (59, "EMERGING", Decimal("5000")),
    (74, "ESTABLISHED", Decimal("15000")),
    (89, "ADVANCED", Decimal("50000")),
    (100, "ELITE", Decimal("100000")),
)


def _clamp(value: Decimal, low: Decimal = Decimal("0"), high: Decimal = Decimal("100")) -> Decimal:
    return max(low, min(high, value))


def performance_score(metrics: CreditMetrics) -> Decimal:
    win = metrics.win_rate * Decimal("100")
    ret = _clamp(metrics.return_on_equity / Decimal("0.90") * Decimal("100"))
    return _clamp(win * Decimal("0.55") + ret * Decimal("0.45"))


def risk_adjusted_score(metrics: CreditMetrics) -> Decimal:
    sharpe = _clamp(metrics.sharpe / Decimal("3.80") * Decimal("100"))
    sortino = _clamp(metrics.sortino / Decimal("5.50") * Decimal("100"))
    return _clamp(sharpe * Decimal("0.70") + sortino * Decimal("0.30"))


def drawdown_score(metrics: CreditMetrics) -> Decimal:
    return _clamp(Decimal("100") - metrics.max_drawdown / Decimal("0.70") * Decimal("100"))


def leverage_score(metrics: CreditMetrics) -> Decimal:
    if metrics.average_leverage <= 0:
        return Decimal("0")
    return _clamp(Decimal("100") - (metrics.average_leverage - Decimal("1")) * Decimal("12"))


def liquidation_score(metrics: CreditMetrics) -> Decimal:
    return _clamp(Decimal("100") - Decimal(metrics.liquidations) * Decimal("40"))


def consistency_score(metrics: CreditMetrics) -> Decimal:
    return _clamp(metrics.consistency * Decimal("100"))


def component_scores(metrics: CreditMetrics) -> dict[str, Decimal]:
    return {
        "performance": performance_score(metrics),
        "risk_adjusted": risk_adjusted_score(metrics),
        "drawdown": drawdown_score(metrics),
        "leverage": leverage_score(metrics),
        "liquidations": liquidation_score(metrics),
        "consistency": consistency_score(metrics),
    }


def weighted_score(components: dict[str, Decimal]) -> int:
    total = sum(components[name] * WEIGHTS[name] for name in WEIGHTS)
    return min(100, max(0, int(total)))


def tier_for_score(score: int) -> tuple[str, Decimal]:
    for ceiling, name, base in TIERS:
        if score <= ceiling:
            return name, base
    return "ELITE", Decimal("100000")


@dataclass(frozen=True)
class CreditEvaluation:
    wallet: str
    score: int
    tier: str
    base_credit: Decimal
    metrics: CreditMetrics
    components: dict[str, Decimal]


def evaluate_trades(wallet: str, trades: list[Trade]) -> CreditEvaluation:
    metrics = compute_metrics(trades)
    if metrics.trade_count == 0:
        zero = {name: Decimal("0") for name in WEIGHTS}
        return CreditEvaluation(
            wallet=wallet.lower(),
            score=0,
            tier="RESTRICTED",
            base_credit=Decimal("0"),
            metrics=metrics,
            components=zero,
        )
    components = component_scores(metrics)
    score = weighted_score(components)
    tier, base = tier_for_score(score)
    return CreditEvaluation(
        wallet=wallet.lower(),
        score=score,
        tier=tier,
        base_credit=base,
        metrics=metrics,
        components=components,
    )


def evaluation_payload(result: CreditEvaluation) -> dict:
    metrics = asdict(result.metrics)
    return {
        "wallet": result.wallet,
        "score": result.score,
        "tier": result.tier,
        "base_credit": format(result.base_credit, "f"),
        "metrics": {
            key: (value if isinstance(value, int) else format(value, "f"))
            for key, value in metrics.items()
        },
        "components": {key: format(value, "f") for key, value in result.components.items()},
    }
