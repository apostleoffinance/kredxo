from decimal import Decimal

from fastapi import APIRouter

from app.config import settings
from app.interest import BASE_APR, UTIL_PREMIUM_MAX, borrow_apr

router = APIRouter(tags=["markets"])


@router.get("/api/markets")
def get_markets() -> dict:
    utilization = Decimal("0")
    tvl = Decimal("0")
    return {
        "base_apr": format(BASE_APR, "f"),
        "utilization_premium_max": format(UTIL_PREMIUM_MAX, "f"),
        "current_apr": format(borrow_apr("NORMAL", utilization), "f"),
        "apr": {
            "low": format(borrow_apr("LOW", Decimal("0")), "f"),
            "normal": format(borrow_apr("NORMAL", utilization), "f"),
            "high": format(borrow_apr("HIGH", Decimal("0.5")), "f"),
        },
        "tvl": format(tvl, "f"),
        "allocated": "0",
        "utilized": "0",
        "utilization": format(utilization, "f"),
        "vault": settings.credit_vault_address or None,
        "usdc": settings.usdc_address or None,
        "policy": settings.risk_policy_address or None,
        "controller": settings.risk_controller_address or None,
        "settlement": settings.settlement_address or None,
        "trading_account": settings.trading_account_address or None,
    }
