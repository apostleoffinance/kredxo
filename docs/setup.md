# Local setup (Phase 1)

Default network is **Monad Testnet**: chain ID `10143`, RPC `https://testnet-rpc.monad.xyz`. Official performance figures for docs: 10,000 TPS, 300ms blocks, 600ms finality.

```bash
cp .env.example .env
```

## Contracts

Requires Foundry v1.8+ (`curl -L https://foundry.paradigm.xyz | bash && foundryup`). Add `export PATH="$PATH:$HOME/.foundry/bin"` to your shell profile.

After cloning, install contract libraries:

```bash
cd contracts
forge install
forge build
forge test
```

## Backend

Postgres is required from Phase 5. For local health checks, start Docker Desktop, then:

```bash
docker compose up -d postgres
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

The Kredxo database is published on **host port 15432** so it does not collide with local Postgres on 5432–5435.

`GET http://localhost:8000/health` should report `monad.rpc_ok: true`, `configured_chain_id: 10143`, and `database.reachable: true`.

## Frontend

```bash
cd frontend
npm install
npm run dev
```

Open `http://localhost:3000`. The terminal has Market, Profile, Account, Trade, and Risk. Unconnected sessions read the seeded demo wallet from the live API.

## Indexer (Phase 5)

```bash
source backend/.venv/bin/activate
export PYTHONPATH=backend
python -m indexer.main check
python -m indexer.main seed
```

Then:

- `GET http://localhost:8000/api/trades/0x83000000000000000000000000000000000009A2` → 120 trades
- `GET http://localhost:8000/api/credit/0x83000000000000000000000000000000000009A2` → score 87, ADVANCED, $50,000 base credit
- `GET http://localhost:8000/api/risk/0x83000000000000000000000000000000000009A2` → current credit, risk state, policy JSON
- `GET http://localhost:8000/api/policy/0x83000000000000000000000000000000000009A2` → Python policy plus onchain units (USDC 6 decimals, leverage WAD)
- `POST http://localhost:8000/policy/propose` → same, with optional market shock overrides
- `POST http://localhost:8000/credit/request` → score, adaptive credit, and onchain policy in one step
- `POST http://localhost:8000/stress/simulate` → HIGH shock, ELEVATED unwind, NORMAL restore, and whether a $20k BTC trade is allowed at each stage

The Phase 9 loop is `backend/tests/test_lifecycle.py` → `contracts/testdata/lifecycle.json` → `forge test --match-contract LifecycleTest`. No frontend required.

The Phase 12 sitting is `POST /stress/simulate` → `contracts/testdata/stress.json` → `forge test --match-contract StressTest`: approve under NORMAL, apply HIGH, $20k BTC reverts, credit restores HIGH → ELEVATED → NORMAL. Risk Center runs the same sitting live. Onchain `applyPolicy` waits for `NEXT_PUBLIC_RISK_CONTROLLER_ADDRESS`.

## Tests (Phase 13)

```bash
scripts/ci.sh
```

Same path as `.github/workflows/test.yml`: `FOUNDRY_ETH_RPC_URL= forge test --offline` then backend pytest (sqlite). Fail-closed invariant: `forge test --match-contract InvariantTest` and `FailClosedTest` — any size over the live BTC cap reverts and leaves exposure unchanged.

`GET http://localhost:8000/api/markets` → borrow APR band (low 7.2%, normal 8%, high 14.5%). Utilized credit accrues interest to vault NAV (`forge test --match-contract InterestTest`).

`python -m indexer.main sync` no-ops until `TRADING_ACCOUNT_ADDRESS` is set.
