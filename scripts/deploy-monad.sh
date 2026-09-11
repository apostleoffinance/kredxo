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
: "${MONAD_CHAIN_ID:=10143}"

if [[ -z "${PRIVATE_KEY:-}" ]]; then
  echo "PRIVATE_KEY is required to broadcast. Set it in .env (do not commit it)." >&2
  exit 1
fi

cd "$ROOT/contracts"
forge script script/Deploy.s.sol:Deploy \
  --rpc-url "$MONAD_RPC_URL" \
  --broadcast \
  --private-key "$PRIVATE_KEY"

echo "Wrote contracts/deployments/monad-testnet.json"
echo "Copy vault / USDC / account / controller addresses into .env and frontend/.env.local"
