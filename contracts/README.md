# Kredxo contracts

Foundry project targeting Monad (EVM-compatible). Default RPC is Monad Testnet (`chain_id = 10143`).

| Contract | Status |
|---|---|
| `KredxoRegistry` | Phase 1 stub |
| `KredxoCreditVault` | Phase 2 — deposit, allocate vs utilize, repay |
| `KredxoTradingAccount` | Phase 4 — controlled account + onchain execute/reject |
| `KredxoRiskPolicy` | Phase 8 |
| `KredxoRiskController` | Phase 8 |
| `KredxoSettlement` | Simplified on the account; dedicated contract in Phase 9 |

```bash
forge build
forge test
```
