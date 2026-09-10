from __future__ import annotations

from dataclasses import dataclass
from decimal import ROUND_DOWN, Decimal

from app.credit.engine import CreditEvaluation

RISK_STATES = ("LOW", "NORMAL", "ELEVATED", "HIGH", "CRITICAL")

STATE_FLOOR = (
    (Decimal("1.05"), "LOW"),
    (Decimal("0.85"), "NORMAL"),
    (Decimal("0.70"), "ELEVATED"),
    (Decimal("0.55"), "HIGH"),
    (Decimal("0"), "CRITICAL"),
)

# Policy fractions are anchored to the published NORMAL / ELEVATED / HIGH examples.
POLICY_BY_STATE = {
    "LOW": {
        "max_leverage": Decimal("5.0"),
        "daily_loss_frac": Decimal("0.04"),
        "btc_frac": Decimal("0.50"),
        "eth_frac": Decimal("0.30"),
    },
    "NORMAL": {
        "max_leverage": Decimal("5.0"),
        "daily_loss_frac": Decimal("0.04"),
        "btc_frac": Decimal("0.50"),
        "eth_frac": Decimal("0.30"),
    },
    "ELEVATED": {
        "max_leverage": Decimal("3.5"),
        "daily_loss_frac": Decimal("1500") / Decimal("36000"),
        "btc_frac": Decimal("15000") / Decimal("36000"),
        "eth_frac": Decimal("10000") / Decimal("36000"),
    },
    "HIGH": {
        "max_leverage": Decimal("3.0"),
        "daily_loss_frac": Decimal("1000") / Decimal("32000"),
        "btc_frac": Decimal("12000") / Decimal("32000"),
        "eth_frac": Decimal("8000") / Decimal("32000"),
    },
    "CRITICAL": {
        "max_leverage": Decimal("1.5"),
        "daily_loss_frac": Decimal("0.02"),
        "btc_frac": Decimal("0.20"),
        "eth_frac": Decimal("0.12"),
    },
}

VOL_BASELINE = Decimal("0.20")
LIQUIDITY_BASELINE = Decimal("1.00")
CORRELATION_BASELINE = Decimal("0.50")
DRAWDOWN_FREE = Decimal("0.10")
LEVERAGE_FREE = Decimal("2.5")
CONCENTRATION_FREE = Decimal("0.55")
ACCOUNT_BUMP_THRESHOLD = Decimal("0.45")


@dataclass(frozen=True)
class TraderSnapshot:
    score: int
    max_drawdown: Decimal
    average_leverage: Decimal
    realized_pnl: Decimal
    concentration: Decimal
    liquidations: int


@dataclass(frozen=True)
class MarketSnapshot:
    volatility: Decimal
    liquidity: Decimal
    price_move: Decimal
    correlation: Decimal
    funding: Decimal


@dataclass(frozen=True)
class AccountSnapshot:
    exposure: Decimal
    utilization: Decimal
    unrealized_pnl: Decimal
    margin: Decimal


@dataclass(frozen=True)
class RiskPolicy:
    credit_limit: Decimal
    max_leverage: Decimal
    daily_loss_limit: Decimal
    markets: dict[str, Decimal]
    risk_level: str


@dataclass(frozen=True)
class RiskEvaluation:
    wallet: str
    base_credit: Decimal
    trader_multiplier: Decimal
    market_multiplier: Decimal
    current_credit: Decimal
    risk_level: str
    trader: TraderSnapshot
    market: MarketSnapshot
    account: AccountSnapshot
    account_stress: Decimal
    policy: RiskPolicy


NORMAL_MARKET = MarketSnapshot(
    volatility=VOL_BASELINE,
    liquidity=LIQUIDITY_BASELINE,
    price_move=Decimal("0"),
    correlation=CORRELATION_BASELINE,
    funding=Decimal("0"),
)

IDLE_ACCOUNT = AccountSnapshot(
    exposure=Decimal("0"),
    utilization=Decimal("0"),
    unrealized_pnl=Decimal("0"),
    margin=Decimal("0"),
)

HEALTHY_TRADER = TraderSnapshot(
    score=87,
    max_drawdown=Decimal("0.05"),
    average_leverage=Decimal("2.0"),
    realized_pnl=Decimal("83420"),
    concentration=Decimal("0.50"),
    liquidations=0,
)


def _dec(value: Decimal | int | float | str) -> Decimal:
    if isinstance(value, Decimal):
        return value
    return Decimal(str(value))


def _clamp(value: Decimal, low: Decimal, high: Decimal) -> Decimal:
    return max(low, min(high, value))


def _floor_dollars(value: Decimal) -> Decimal:
    return value.quantize(Decimal("1"), rounding=ROUND_DOWN)


def _one_decimal(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.1"), rounding=ROUND_DOWN)


def current_credit(base_credit: Decimal, trader_multiplier: Decimal, market_multiplier: Decimal) -> Decimal:
    """Current Credit = Base Credit × Trader Risk Multiplier × Market Risk Multiplier."""
    return _floor_dollars(_dec(base_credit) * _dec(trader_multiplier) * _dec(market_multiplier))


def trader_multiplier(trader: TraderSnapshot) -> Decimal:
    penalty = Decimal("0")
    penalty += Decimal("0.004") * Decimal(max(0, 75 - trader.score))
    penalty += Decimal("1.00") * max(Decimal("0"), trader.max_drawdown - DRAWDOWN_FREE)
    penalty += Decimal("0.08") * max(Decimal("0"), trader.average_leverage - LEVERAGE_FREE)
    penalty += Decimal("0.18") * Decimal(trader.liquidations)
    penalty += Decimal("0.30") * max(Decimal("0"), trader.concentration - CONCENTRATION_FREE)
    return _clamp(Decimal("1.00") - penalty, Decimal("0.50"), Decimal("1.10"))


def market_multiplier(market: MarketSnapshot) -> Decimal:
    penalty = Decimal("0")
    penalty += Decimal("0.80") * max(Decimal("0"), market.volatility - VOL_BASELINE)
    penalty += Decimal("0.50") * max(Decimal("0"), LIQUIDITY_BASELINE - market.liquidity)
    penalty += Decimal("0.50") * abs(market.price_move)
    penalty += Decimal("0.12") * max(Decimal("0"), market.correlation - CORRELATION_BASELINE)
    penalty += Decimal("0.20") * max(Decimal("0"), market.funding)
    return _clamp(Decimal("1.00") - penalty, Decimal("0.50"), Decimal("1.10"))


def shocked_market(base: MarketSnapshot = NORMAL_MARKET) -> MarketSnapshot:
    """Documented HIGH shock: vol +85%, liquidity -28%, BTC drawdown -12%, correlation +20%."""
    return MarketSnapshot(
        volatility=base.volatility * Decimal("1.85"),
        liquidity=base.liquidity * Decimal("0.72"),
        price_move=Decimal("0.12"),
        correlation=base.correlation + Decimal("0.20"),
        funding=base.funding,
    )


def recovering_market(base: MarketSnapshot = NORMAL_MARKET) -> MarketSnapshot:
    """Halfway unwind after HIGH. Healthy $50K base → ELEVATED ~$41K."""
    return MarketSnapshot(
        volatility=Decimal("0.285"),
        liquidity=Decimal("0.86"),
        price_move=Decimal("0.06"),
        correlation=Decimal("0.60"),
        funding=base.funding,
    )


def distance_to_liquidation(account: AccountSnapshot) -> Decimal:
    if account.margin <= 0:
        return Decimal("1")
    return _clamp(Decimal("1") + account.unrealized_pnl / account.margin, Decimal("0"), Decimal("1"))


def account_stress(account: AccountSnapshot, base_credit: Decimal) -> Decimal:
    capacity = base_credit if base_credit > 0 else Decimal("1")
    exposure_over = max(Decimal("0"), account.exposure / capacity - Decimal("0.50"))
    stress = (
        account.utilization * Decimal("0.60")
        + exposure_over * Decimal("0.40")
        + (Decimal("1") - distance_to_liquidation(account)) * Decimal("0.30")
    )
    return _clamp(stress, Decimal("0"), Decimal("1"))


def risk_state(product: Decimal, stress: Decimal = Decimal("0")) -> str:
    level = "CRITICAL"
    for floor, name in STATE_FLOOR:
        if product >= floor:
            level = name
            break
    if stress >= ACCOUNT_BUMP_THRESHOLD:
        idx = RISK_STATES.index(level)
        level = RISK_STATES[min(idx + 1, len(RISK_STATES) - 1)]
    return level


def build_policy(current: Decimal, state: str) -> RiskPolicy:
    spec = POLICY_BY_STATE[state]
    if current <= 0:
        return RiskPolicy(
            credit_limit=Decimal("0"),
            max_leverage=Decimal("1.0"),
            daily_loss_limit=Decimal("0"),
            markets={"BTC": Decimal("0"), "ETH": Decimal("0")},
            risk_level=state,
        )
    return RiskPolicy(
        credit_limit=current,
        max_leverage=_one_decimal(spec["max_leverage"]),
        daily_loss_limit=_floor_dollars(current * spec["daily_loss_frac"]),
        markets={
            "BTC": _floor_dollars(current * spec["btc_frac"]),
            "ETH": _floor_dollars(current * spec["eth_frac"]),
        },
        risk_level=state,
    )


def trader_from_credit(result: CreditEvaluation) -> TraderSnapshot:
    return TraderSnapshot(
        score=result.score,
        max_drawdown=result.metrics.max_drawdown,
        average_leverage=result.metrics.average_leverage,
        realized_pnl=result.metrics.realized_pnl,
        concentration=result.metrics.concentration,
        liquidations=result.metrics.liquidations,
    )


def evaluate_risk(
    wallet: str,
    base_credit: Decimal,
    trader: TraderSnapshot,
    market: MarketSnapshot = NORMAL_MARKET,
    account: AccountSnapshot = IDLE_ACCOUNT,
) -> RiskEvaluation:
    if base_credit <= 0:
        policy = build_policy(Decimal("0"), "CRITICAL")
        return RiskEvaluation(
            wallet=wallet.lower(),
            base_credit=Decimal("0"),
            trader_multiplier=Decimal("0"),
            market_multiplier=Decimal("0"),
            current_credit=Decimal("0"),
            risk_level="CRITICAL",
            trader=trader,
            market=market,
            account=account,
            account_stress=account_stress(account, Decimal("0")),
            policy=policy,
        )

    t_mult = trader_multiplier(trader)
    m_mult = market_multiplier(market)
    credit = current_credit(base_credit, t_mult, m_mult)
    stress = account_stress(account, base_credit)
    state = risk_state(t_mult * m_mult, stress)
    policy = build_policy(credit, state)
    return RiskEvaluation(
        wallet=wallet.lower(),
        base_credit=base_credit,
        trader_multiplier=t_mult,
        market_multiplier=m_mult,
        current_credit=credit,
        risk_level=state,
        trader=trader,
        market=market,
        account=account,
        account_stress=stress,
        policy=policy,
    )


def evaluate_from_credit(
    result: CreditEvaluation,
    market: MarketSnapshot = NORMAL_MARKET,
    account: AccountSnapshot = IDLE_ACCOUNT,
) -> RiskEvaluation:
    return evaluate_risk(
        wallet=result.wallet,
        base_credit=result.base_credit,
        trader=trader_from_credit(result),
        market=market,
        account=account,
    )


def _fmt(value: Decimal) -> str:
    return format(value.quantize(Decimal("0.000001")), "f")


def policy_payload(policy: RiskPolicy) -> dict:
    return {
        "creditLimit": int(policy.credit_limit),
        "maxLeverage": float(policy.max_leverage),
        "dailyLossLimit": int(policy.daily_loss_limit),
        "markets": {name: int(limit) for name, limit in policy.markets.items()},
        "riskLevel": policy.risk_level,
    }


def evaluation_payload(result: RiskEvaluation) -> dict:
    return {
        "wallet": result.wallet,
        "base_credit": _fmt(result.base_credit),
        "current_credit": _fmt(result.current_credit),
        "trader_multiplier": _fmt(result.trader_multiplier),
        "market_multiplier": _fmt(result.market_multiplier),
        "risk_level": result.risk_level,
        "trader_risk": {
            "score": result.trader.score,
            "max_drawdown": _fmt(result.trader.max_drawdown),
            "average_leverage": _fmt(result.trader.average_leverage),
            "realized_pnl": _fmt(result.trader.realized_pnl),
            "concentration": _fmt(result.trader.concentration),
            "liquidations": result.trader.liquidations,
        },
        "market_risk": {
            "volatility": _fmt(result.market.volatility),
            "liquidity": _fmt(result.market.liquidity),
            "price_move": _fmt(result.market.price_move),
            "correlation": _fmt(result.market.correlation),
            "funding": _fmt(result.market.funding),
        },
        "account_risk": {
            "exposure": _fmt(result.account.exposure),
            "utilization": _fmt(result.account.utilization),
            "unrealized_pnl": _fmt(result.account.unrealized_pnl),
            "margin": _fmt(result.account.margin),
            "distance_to_liquidation": _fmt(distance_to_liquidation(result.account)),
            "stress": _fmt(result.account_stress),
        },
        "policy": policy_payload(result.policy),
    }
