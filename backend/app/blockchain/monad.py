import httpx

from app.config import settings


def fetch_chain_id() -> int | None:
    payload = {"jsonrpc": "2.0", "id": 1, "method": "eth_chainId", "params": []}
    try:
        response = httpx.post(settings.monad_rpc_url, json=payload, timeout=8.0)
        response.raise_for_status()
        result = response.json().get("result")
        return int(result, 16) if result else None
    except Exception:
        return None
