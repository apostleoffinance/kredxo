from __future__ import annotations

import json
from typing import Any

import httpx


def rpc_call(url: str, method: str, params: list[Any]) -> Any:
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    response = httpx.post(url, json=payload, timeout=20.0)
    response.raise_for_status()
    body = response.json()
    if "error" in body:
        raise RuntimeError(json.dumps(body["error"]))
    return body["result"]


def get_chain_id(url: str) -> int:
    return int(rpc_call(url, "eth_chainId", []), 16)


def get_block_number(url: str) -> int:
    return int(rpc_call(url, "eth_blockNumber", []), 16)


def get_logs(url: str, address: str, from_block: int, to_block: int, topics: list[str]) -> list[dict]:
    return rpc_call(
        url,
        "eth_getLogs",
        [
            {
                "address": address,
                "fromBlock": hex(from_block),
                "toBlock": hex(to_block),
                "topics": [topics],
            }
        ],
    )


def get_block_timestamp(url: str, block_hex: str) -> int:
    block = rpc_call(url, "eth_getBlockByNumber", [block_hex, False])
    return int(block["timestamp"], 16)
