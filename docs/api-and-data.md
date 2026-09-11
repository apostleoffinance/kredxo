# API and data

Offchain contract between the risk/credit engines, Postgres, and the frontend. Monad remains the source of truth for enforcement.

## API

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/credit/{wallet}` | Score, tier, base credit, metrics |
| GET | `/api/risk/{wallet}` | Risk state and multipliers |
| GET | `/api/policy/{wallet}` | Current trading authority |
| GET | `/api/trades/{wallet}` | Trade history (`count`, `volume`, `realized_pnl`, `trades`) |
| GET | `/api/positions/{wallet}` | Open positions |
| GET | `/api/markets` | APR band, base rate, utilization premium (TVL wired in Phase 11) |
| POST | `/credit/evaluate` | Recompute score and base credit |
| POST | `/credit/request` | Full request: score → adaptive credit → policy (onchain units) |
| POST | `/risk/evaluate` | Recompute adaptive risk |
| POST | `/policy/propose` | Sign/authorize onchain policy update |
| GET | `/api/demo` | Submission snapshot: addresses, explorer, sitting, venues (hop Circle USDC → venue token on the Credit Account) |
| POST | `/stress/simulate` | HIGH shock → ELEVATED → NORMAL sitting and $20k BTC probe |

## Postgres

`users`, `wallets`, `trades`, `positions`, `markets`, `credit_profiles`, `credit_scores`, `risk_scores`, `risk_events`, `credit_accounts`, `credit_vaults`, `risk_policies`, `policy_history`.

### `trades`

`id`, `wallet`, `market`, `side`, `size`, `entry_price`, `exit_price`, `pnl`, `leverage`, `timestamp`, `tx_hash`

## Frontend routes

| Screen | Job |
|---|---|
| Demo | Sitting, onchain vs Python credit, explorer links |
| Market | TVL, utilization, APR, Supply USDC |
| Credit Profile | Score, tier, metrics, Request Credit |
| Credit Account | Current/used/available, risk, limits |
| Trade | Venue (internal / Perpl / Kuru), size, leverage, onchain checks, execute/reject |
| Risk Center | Multipliers, HIGH → ELEVATED → NORMAL sitting, `SIMULATE MARKET STRESS` |
