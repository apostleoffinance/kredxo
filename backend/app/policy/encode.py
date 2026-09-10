from __future__ import annotations

from decimal import Decimal

from app.risk.engine import RiskPolicy

USDC_DECIMALS = Decimal("1000000")
WAD = Decimal("1000000000000000000")
LEVELS = {"LOW": 0, "NORMAL": 1, "ELEVATED": 2, "HIGH": 3, "CRITICAL": 4}
DEFAULT_VALIDITY_SECONDS = 24 * 60 * 60


def onchain_policy(policy: RiskPolicy, valid_from: int, valid_until: int) -> dict:
    return {
        "creditLimit": int(policy.credit_limit * USDC_DECIMALS),
        "maxLeverage": int(policy.max_leverage * WAD),
        "dailyLossLimit": int(policy.daily_loss_limit * USDC_DECIMALS),
        "validFrom": valid_from,
        "validUntil": valid_until,
        "riskLevel": LEVELS[policy.risk_level],
        "active": True,
        "markets": [
            {"symbol": name, "limit": int(limit * USDC_DECIMALS)}
            for name, limit in policy.markets.items()
        ],
    }
