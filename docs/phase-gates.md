# Phase gates

Do not start the next phase until **every** checkbox in the current phase is true. Update `docs/CURRENT_PHASE.md` when a phase is completed.

Source of truth for hackathon scope. If time is tight, still finish all P0 items before P1.

---

## Phase 0 — Freeze the protocol specification

- [x] Four actors defined: LP, Trader, Risk Engine, Protocol
- [x] Master lifecycle written
- [x] Onchain vs offchain split agreed
- [x] Out-of-scope list agreed

**Safe to proceed when:** anyone can explain Kredxo without calling it a lending protocol.

**Status:** complete (2026-09-10)

---

## Phase 1 — Repository & infrastructure

- [x] Monorepo: `contracts/`, `backend/`, `frontend/`, `indexer/`, `scripts/`, `docs/`
- [x] Foundry + OpenZeppelin initialized
- [x] FastAPI + PostgreSQL scaffolded
- [x] Next.js / TypeScript / Tailwind / wagmi / viem scaffolded
- [x] Monad RPC / env configured
- [x] Contract stubs only: Registry, Vault, TradingAccount first

**Safe to proceed when:** Foundry, FastAPI, and Next.js all boot locally against Monad config.

**Status:** complete (2026-09-10)

---

## Phase 2 — USDC Credit Vault (P0)

- [x] `deposit` / `withdraw`
- [x] `allocateCredit` / `releaseCredit` / `repay`
- [x] Tracks `totalAssets`, `totalShares`, `availableLiquidity`, `allocatedCredit`, `utilizedCredit`
- [x] Committed credit ≠ utilization
- [x] Vault tests pass

**Safe to proceed when:** LP deposits USDC and vault accounting is correct at zero utilization.

**Status:** complete (2026-09-10)


---

## Phase 3 — Trader Credit Account (P0)

- [x] Account holds credit; trader cannot withdraw unrestricted USDC
- [x] State: trader, creditLimit, usedCredit, collateral, maxLeverage, dailyLossLimit, active
- [x] Position struct exists
- [x] Account bound to the vault
- [x] Account tests pass

**Safe to proceed when:** credit lives in a controlled account, not the trader wallet.

**Status:** complete (2026-09-10)


---

## Phase 4 — Trading / settlement (P0)

- [x] One simplified Monad-native execution path (no multi-venue)
- [x] Checks: active, market, credit, leverage, position limit, daily loss
- [x] Onchain `TradeApproved`
- [x] Onchain `TradeRejected` with reason
- [x] Frontend cannot bypass rejection

**Safe to proceed when:** a valid trade succeeds and an over-limit trade reverts onchain.

**Status:** complete (2026-09-10)

---

## Phase 5 — Trading data pipeline

- [x] Monad RPC → indexer → PostgreSQL
- [x] `trades` table with wallet, market, side, size, prices, pnl, leverage, timestamp, tx_hash
- [x] Historical trades ingest for a wallet

**Safe to proceed when:** a demo wallet’s history can be read from Postgres.

**Status:** complete (2026-09-10)

---

## Phase 6 — Credit intelligence (P0)

- [x] Metrics: PnL, return, win rate, Sharpe, Sortino, drawdown, leverage, liquidations, concentration, consistency
- [x] Score formula implemented (see `docs/credit-model.md`)
- [x] Score → tier → base credit
- [x] Python tests: high Sharpe ↑ score, high drawdown ↓, liquidation ↓

**Safe to proceed when:** seeded history produces Score 87 / Advanced / $50K.

**Status:** complete (2026-09-10)

---

## Phase 7 — Adaptive risk engine (P0)

- [x] Inputs: trader risk + market risk + account risk
- [x] States: LOW / NORMAL / ELEVATED / HIGH / CRITICAL
- [x] Adaptive credit formula implemented (see `docs/risk-model.md`)
- [x] Policy JSON: creditLimit, maxLeverage, dailyLossLimit, market limits, riskLevel
- [x] Tests: high vol / low liquidity / concentration reduce credit

**Safe to proceed when:** $50K × 0.90 × 0.80 = $36K and a HIGH shock produces a tighter policy.

**Status:** complete (2026-09-10)

---

## Phase 8 — Onchain risk policy (P0)

- [x] `KredxoRiskPolicy` stores limits, validity window, riskLevel, market position limits
- [x] `KredxoRiskController` is the only updater (`RISK_CONTROLLER_ROLE`)
- [x] Updates emit `PolicyUpdated`, `CreditAdjusted`, `RiskLevelChanged`
- [x] Trading account reads the current policy, not a UI cache
- [x] Stale/expired policy cannot be used to trade

**Safe to proceed when:** a Python-proposed policy is enforced by the contract.

**Status:** complete (2026-09-10)

---

## Phase 9 — End-to-end credit lifecycle

- [x] LP deposit → vault → request → score → base credit → adaptive credit → policy → account → trade → PnL → policy change
- [x] Integration test: Python → policy → contract → trade

**Safe to proceed when:** the loop works without the frontend.

**Status:** complete (2026-09-10)

---

## Phase 10 — Interest & LP economics (P1)

- [x] Borrow APR = 8% + risk + utilization premia
- [x] Interest accrues to the vault / LPs
- [x] Accounting stays simple

**Safe to proceed when:** a utilized position produces LP yield.

**Status:** complete (2026-09-10)

---

## Phase 11 — Frontend

Only after the onchain loop works. Five screens:

- [x] Market — TVL, utilization, APR, Supply USDC
- [x] Credit Profile — score, tier, request credit
- [x] Credit Account — current/used/available, risk, limits
- [x] Trade — review checks + execute
- [x] Risk Center — multipliers and policy diffs

Feel: serious financial terminal, not a typical DeFi dashboard.

**Safe to proceed when:** every screen reads live protocol/backend state, not mocked copy.

**Status:** complete (2026-09-10)

---

## Phase 12 — Stress simulation (P1)

- [x] `SIMULATE MARKET STRESS` injects vol/liquidity/drawdown/correlation
- [x] Policy updates onchain
- [x] Previously valid trade is rejected
- [x] Recovery: HIGH → ELEVATED → NORMAL and credit restores

**Safe to proceed when:** approve → shock → reject → recover works in one sitting.

**Status:** complete (2026-09-10)

---

## Phase 13 — Testing

- [x] Solidity: deposit, withdraw, allocate, repay, policy, approve, reject
- [x] Python credit/risk tests
- [x] Integration tests for the full loop
- [x] Invariant test fails closed (over-limit trade always reverts)

**Safe to proceed when:** the invariant holds in CI.

**Status:** complete (2026-09-10)

---

## Phase 14 — Security

- [x] Access control, reentrancy, precision
- [x] Unauthorized allocation / policy updates blocked
- [x] Withdrawal and accounting consistency
- [x] Stale/expired policies cannot authorize trades
- [x] Invariant: no trade beyond the active policy

**Safe to proceed when:** the invariant holds without trusting the frontend.

**Status:** complete (2026-09-11)

---

## Phase 15 — Monad deployment

- [x] Deploy: Registry → Vault → Risk Policy → Risk Controller → Trading Account → Settlement
- [x] Configure USDC, controller, vault, venue, markets

**Status:** complete (2026-09-11) — `scripts/deploy-monad.sh` broadcasts `Deploy.s.sol`. Official testnet USDC `0x534b2f3A21130d7a60830c2Df862319e593943A3`. Addresses land in `contracts/deployments/monad-testnet.json`.

---

## Phase 16 — Seed the demo

- [x] Demo LP with 100,000 USDC
- [x] Demo trader: 100+ trades, ~$1.8M volume, ~$83K PnL, 8.7% max DD, 0 liquidations → score 87 / $50K

**Status:** complete (2026-09-11) — `python -m indexer.main seed` writes the 120-trade book. `scripts/seed-demo.sh` deposits up to 100,000 USDC, allocates $50K (or the faucet balance if smaller), applies NORMAL policy, and activates the account.

---

## Phase 17 — Demo + submission

- [x] 2-minute pitch (`docs/pitch.md`)
- [x] 3-minute technical demo (`docs/demo.md`)
- [x] Submission packet: addresses, credentials, live app (`docs/submission.md`)
- [x] Demo screen at `/demo`
- [x] Tests: `scripts/ci.sh` (health `phase: 17`)

Canonical 2–3 minute story (Foundry `LifecycleTest` / `StressTest`):

1. LP deposits $100K
2. Trader connects; score 87 / $50K base
3. Credit issued onchain (`CreditIssued`)
4. $10K BTC trade approved
5. Simulate market stress
6. Credit $50K → $32K; leverage 5x → 3x; BTC $25K → $12K
7. $20K BTC **rejected onchain**
8. Recovery $32K → $41K → $50K

Live Monad Testnet seed used Circle faucet USDC: $20 deposit, $20 credit, $10 BTC cap. Same loop; sizes match inventory.

**Status:** complete (2026-09-11) — UI, tests, docs, pitch, demo script, contract addresses, test credentials. Record the sitting from `docs/demo.md`; do not redeploy.

---

## Phase 18 — Execution router (Perpl + Kuru)

- [x] `ExecutionRouter` — `execute(venue, action, data)`; does not hold funds; no arbitrary calldata
- [x] Protocol allowlist (venue, action, asset, target contract)
- [x] Adapter 0: existing internal BTC/ETH `executeTrade` still works
- [x] Perpl adapter (perps) — match chain; do not call mainnet 143 from testnet 10143 vault
- [x] Kuru adapter (spot) — same chain/allowlist rules
- [x] Policy gates venue + action + size; over-limit still reverts onchain
- [x] Aave **not** in this phase (supply later; borrow later still)

**Safe to proceed when:** a Credit Account can deploy only to allowlisted Perpl and/or Kuru under the live policy, internal sitting still passes, and USDC cannot leave via an unlisted target.

**Status:** complete (2026-09-11) — Foundry `ExecutionRouterTest`. Router is not broadcast on the Phase 17 testnet vault; Internal `executeTrade` remains the live path. Official Kuru/Perpl testnet addresses confirmed; vault Circle USDC does not match either venue token (`KredxoWrongAsset`).

---

## Phase 19 — Venue FX hop (Circle USDC → venue token)

- [x] Typed hop: Credit Account pays Circle USDC to the Kuru adapter, not the official Kuru router
- [x] `anyToAnySwap` path is admin-set; no Kuru Flow / arbitrary calldata
- [x] Output venue token (tUSDC / Perpl collateral) returns to the Credit Account
- [x] Perpl open hops then `payVenueToken`; no hop → revert before Circle reaches Perpl
- [x] Trader cannot withdraw; Internal `executeTrade` still works
- [x] Aave **not** in this phase

**Safe to proceed when:** a Foundry hop converts vault USDC to the venue token on the account, a missing path reverts without paying the venue, and the Phase 17 sitting vault is unchanged.

**Status:** complete (2026-09-11) — Foundry `ExecutionRouterTest` (hop cases). Not broadcast. Live sitting remains Internal.

---

## Definition of done

LP deposits USDC → trader receives history-based credit → onchain trade → market risk rises → Kredxo reduces credit/policy → the smart contract rejects a now-over-limit trade → market recovers → credit increases again. All with real Monad transactions.

---

## Sprint 1 (days 1–7) if starting development today

| Day | Work |
|---|---|
| 1 | GitHub repo, Foundry, Next.js, FastAPI, Monad network, env vars |
| 2 | Registry, CreditVault, vault tests |
| 3 | TradingAccount, bind to vault, account tests |
| 4 | RiskPolicy, RiskController, policy tests |
| 5 | Simple execution, validation, onchain rejection |
| 6–7 | Database, trade ingestion, initial credit scoring |

Then: week 2 credit intelligence → week 3 adaptive risk → week 4 onchain enforcement + trading → week 5 frontend + stress → week 6 testing + deploy + demo.
