#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

: "${MONAD_RPC_URL:=https://testnet-rpc.monad.xyz}"

if [[ -z "${PRIVATE_KEY:-}" ]]; then
  echo "PRIVATE_KEY is required to broadcast. Set it in .env (do not commit it)." >&2
  exit 1
fi
if [[ -z "${CREDIT_VAULT_ADDRESS:-}" || -z "${USDC_ADDRESS:-}" || -z "${TRADING_ACCOUNT_ADDRESS:-}" || -z "${RISK_CONTROLLER_ADDRESS:-}" ]]; then
  echo "Set CREDIT_VAULT_ADDRESS, USDC_ADDRESS, TRADING_ACCOUNT_ADDRESS, RISK_CONTROLLER_ADDRESS from deployments/monad-testnet.json" >&2
  exit 1
fi

if [[ -d "$ROOT/backend/.venv" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/backend/.venv/bin/activate"
fi
export PYTHONPATH="${ROOT}/backend${PYTHONPATH:+:$PYTHONPATH}"
python -m indexer.main seed --wallet "${DEMO_WALLET:-0x83000000000000000000000000000000000009A2}"

cd "$ROOT/contracts"
forge script script/SeedDemo.s.sol:SeedDemo \
  --rpc-url "$MONAD_RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY"
