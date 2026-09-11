# Kredxo contracts

Foundry project targeting Monad (EVM-compatible). Default RPC is Monad Testnet (`chain_id = 10143`).

| Contract | Status |
|---|---|
| `KredxoRegistry` | Phase 1 stub |
| `KredxoCreditVault` | Phase 2 — deposit, allocate vs utilize, repay |
| `KredxoTradingAccount` | Phase 4 — controlled account + onchain execute/reject |
| `KredxoRiskPolicy` | Phase 8 |
| `KredxoRiskController` | Phase 8 |
| `KredxoSettlement` | Phase 15 — venue + BTC/ETH market config; PnL/repay stay on the account and vault |
| `KredxoExecutionRouter` | Phase 19 — Perpl + Kuru allowlist; Circle USDC hops to venue token on the Credit Account |

`FOUNDRY_ETH_RPC_URL= forge test --offline --match-contract ExecutionRouterTest`

```bash
forge build
forge test
# Monad testnet (requires PRIVATE_KEY in ../.env)
../scripts/deploy-monad.sh
```
