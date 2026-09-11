from pathlib import Path
import json

from fastapi import APIRouter

from app.config import settings

router = APIRouter(tags=["demo"])

DEPLOYMENTS = Path(__file__).resolve().parents[3] / "contracts" / "deployments" / "monad-testnet.json"

_CANONICAL = {
    "lp_deposit_usdc": 100_000,
    "score": 87,
    "tier": "ADVANCED",
    "base_credit": 50_000,
    "approved_btc": 10_000,
    "rejected_btc": 20_000,
    "shock_credit": 32_000,
    "elevated_credit": 41_000,
}

_LIVE = {
    "lp_deposit_usdc": 20,
    "score": 87,
    "tier": "ADVANCED",
    "base_credit_python": 50_000,
    "onchain_credit": 20,
    "btc_cap": 10,
    "note": "Issued credit never exceeds vault deposit. Python $50k is a recommendation.",
}


def _deployments() -> dict:
    if DEPLOYMENTS.is_file():
        return json.loads(DEPLOYMENTS.read_text())
    return {}


@router.get("/api/demo")
def get_demo() -> dict:
    d = _deployments()
    explorer = settings.monad_explorer_url.rstrip("/")
    contracts = {
        "usdc": settings.usdc_address or d.get("usdc"),
        "registry": d.get("registry"),
        "vault": settings.credit_vault_address or d.get("vault"),
        "policy": settings.risk_policy_address or d.get("policy"),
        "controller": settings.risk_controller_address or d.get("controller"),
        "tradingAccount": settings.trading_account_address or d.get("tradingAccount"),
        "settlement": settings.settlement_address or d.get("settlement"),
        "btc": d.get("btc"),
        "eth": d.get("eth"),
    }
    return {
        "phase": 19,
        "product": {
            "tagline": "Adaptive Credit Infrastructure for Onchain Markets",
            "one_liner": "Kredxo turns trading history into adaptive onchain credit.",
            "principle": "Python decides. Solidity enforces.",
        },
        "network": {
            "name": "Monad Testnet",
            "chain_id": settings.monad_chain_id,
            "rpc_url": settings.monad_rpc_url,
            "explorer": explorer,
            "tps": 10_000,
            "block_frequency_ms": 300,
            "finality_ms": 600,
        },
        "demo_wallet": settings.demo_wallet,
        "lp": d.get("lp"),
        "contracts": contracts,
        "seed": d.get("seed"),
        "sitting": {"canonical": _CANONICAL, "live": _LIVE},
        "venues": {
            "adapter0": "internal",
            "first": "perpl",
            "second": "kuru",
            "later": "aave-supply",
            "not_this_phase": ["aave-borrow", "drake", "morpho", "euler", "uniswap"],
            "testnet": {
                "chain_id": 10143,
                "kuru_router": "0x7EFbE105Ca7415dE98F96622173458ac1c054630",
                "kuru_usdc": "0x3bA3d39AFcf8bb994f7964B3e0171Ea2Ba361570",
                "perpl_exchange": "0x1964C32f0bE608E7D29302AFF5E61268E72080cc",
                "perpl_collateral": "0xdF5B718d8FcC173335185a2a1513eE8151e3c027",
                "vault_usdc": "0x534b2f3A21130d7a60830c2Df862319e593943A3",
                "kuru_usdc_match": False,
                "perpl_collateral_match": False,
            },
            "pay_venue": "hop Circle USDC to venue token on the Credit Account; never pay official routers Circle directly",
        },
        "explorer": explorer,
    }
