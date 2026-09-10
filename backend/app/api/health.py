from fastapi import APIRouter

from app.blockchain.monad import fetch_chain_id
from app.config import settings
from app.db import ping_database

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict:
    live_chain_id = fetch_chain_id()
    return {
        "status": "ok",
        "phase": 13,
        "service": "kredxo-backend",
        "env": settings.kredxo_env,
        "database": {"configured": True, "reachable": ping_database()},
        "monad": {
            "network": settings.monad_network,
            "configured_chain_id": settings.monad_chain_id,
            "rpc_url": settings.monad_rpc_url,
            "explorer_url": settings.monad_explorer_url,
            "native_symbol": settings.monad_native_symbol,
            "live_chain_id": live_chain_id,
            "rpc_ok": live_chain_id == settings.monad_chain_id,
        },
    }
