#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

RPC_URL="${MONAD_RPC_URL:-https://testnet-rpc.monad.xyz}"
EXPECTED="${MONAD_CHAIN_ID:-10143}"

LIVE_HEX="$(curl -sS "$RPC_URL" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"])')"

LIVE=$((LIVE_HEX))

echo "rpc=$RPC_URL"
echo "configured_chain_id=$EXPECTED"
echo "live_chain_id=$LIVE"

if [[ "$LIVE" -ne "$EXPECTED" ]]; then
  echo "error: chain id mismatch" >&2
  exit 1
fi

echo "monad rpc ok"
