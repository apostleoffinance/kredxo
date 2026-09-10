#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FOUNDRY_ETH_RPC_URL=

(cd "$ROOT/contracts" && forge build && forge test --offline)

if [[ -x "$ROOT/backend/.venv/bin/pytest" ]]; then
  (cd "$ROOT/backend" && .venv/bin/pytest -q)
else
  (cd "$ROOT/backend" && pytest -q)
fi
