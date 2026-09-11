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

Open `http://localhost:3000`. Start on **Demo**, then Market, Profile, Account, Trade, and Risk. Unconnected sessions read the seeded demo wallet from the live API.

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

Same path as `.github/workflows/test.yml`: `forge build` (fetches solc 0.8.24) then `FOUNDRY_ETH_RPC_URL= forge test --offline`, then backend pytest (sqlite). Fail-closed invariant: `forge test --match-contract InvariantTest` and `FailClosedTest` — any size over the live BTC cap reverts and leaves exposure unchanged.

Phase 14 security is `forge test --match-contract SecurityTest`: strangers cannot allocate or write policy, expired/future policy cannot trade, a losing close does not inflate NAV, withdraw is non-reentrant, and over-limit size always reverts without the frontend.

## Monad deployment (Phase 15)

Order: Registry → Vault → Risk Policy → Risk Controller → Trading Account → Settlement.

```bash
# in .env
PRIVATE_KEY=          # deployer; never commit
USDC_ADDRESS=0x534b2f3A21130d7a60830c2Df862319e593943A3
KREDXO_TRADER=0x83000000000000000000000000000000000009A2
# DEPLOY_MOCK_USDC=true   # only if you cannot use official testnet USDC

scripts/deploy-monad.sh
```

Official Monad Testnet USDC is `0x534b2f3A21130d7a60830c2Df862319e593943A3` (6 decimals). The script binds the controller, vault, trading account, venue, and BTC/ETH markets (`0x…0b7c` / `0x…0e7c`). Copy the addresses from `contracts/deployments/monad-testnet.json` into `.env` and `frontend/.env.local`.

`forge test --match-contract DeployTest` proves the same wiring without broadcasting.

## Seed the demo (Phase 16)

```bash
# history (Postgres): 120 trades, $83,420 PnL, score 87 / $50K
python -m indexer.main seed

# onchain LP + credit (needs USDC in the deployer wallet)
scripts/seed-demo.sh
```

Target is 100,000 USDC in the vault and $50K allocated to `0x8300…09A2`. If the Circle faucet only sent 20 USDC, the script deposits that and issues matching credit. `LP_DEPOSIT_USDC` and `CREDIT_LIMIT_USDC` are 6-decimal units (`100000000000` = $100,000).

`forge test --match-contract SeedDemoTest` runs the $100K sitting and a 20 USDC faucet-sized sitting without broadcasting.

`GET http://localhost:8000/api/markets` → borrow APR band (low 7.2%, normal 8%, high 14.5%). Utilized credit accrues interest to vault NAV (`forge test --match-contract InterestTest`).

`python -m indexer.main sync` no-ops until `TRADING_ACCOUNT_ADDRESS` is set.

## Demo + submission (Phase 17)

```bash
# UI sitting
open http://localhost:3000/demo
```

Packet: `docs/submission.md` (addresses, credentials), `docs/pitch.md`, `docs/demo.md`. Health reports `phase: 19`. Do not redeploy or re-run `seed-demo.sh`.

## Execution router (Phase 18–19)

Perpl (perps) then Kuru (spot). Phase 19 hops Circle USDC to the venue token on the Credit Account. Internal BTC/ETH book stays adapter 0. Aave is not in this phase. Official addresses: `docs/venues.md`. Do not call Monad mainnet venues from the testnet vault. Proof: `FOUNDRY_ETH_RPC_URL= forge test --offline --match-contract ExecutionRouterTest`. See `docs/CURRENT_PHASE.md`.
