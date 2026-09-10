from __future__ import annotations

from decimal import Decimal

BASE_APR = Decimal("0.08")
UTIL_PREMIUM_MAX = Decimal("0.05")
RISK_PREMIUM = {
    "LOW": Decimal("-0.008"),
    "NORMAL": Decimal("0"),
    "ELEVATED": Decimal("0.02"),
    "HIGH": Decimal("0.04"),
    "CRITICAL": Decimal("0.065"),
}


def borrow_apr(risk_level: str, utilization: Decimal) -> Decimal:
    """Borrow APR = 8% + risk premium + utilization premium."""
    util = min(max(utilization, Decimal("0")), Decimal("1"))
    apr = BASE_APR + RISK_PREMIUM[risk_level] + UTIL_PREMIUM_MAX * util
    return max(apr, Decimal("0"))
