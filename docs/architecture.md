# Architecture

Kredxo connects capital providers with traders, quantitative strategies, and eventually autonomous agents. It does not simply lend money. It determines who deserves trading credit, how much, what they may do with it, and when those limits must change.

## Loop

```
Trading History
       ↓
Credit Intelligence
       ↓
Trader Risk Profile
       ↓
Credit Capacity
       ↓
Market Risk Assessment
       ↓
Adaptive Credit
       ↓
Programmable Trading Policy
       ↓
Credit Account
       ↓
Trade Execution
       ↓
New Trading Data
       ↓
Continuous Reassessment
       ↺
```

Short form: **Credit Intelligence → Adaptive Risk → Programmable Policy → Execution → Reassessment**

## Participants

| Side | Who | What they do |
|---|---|---|
| Capital | DeFi users, funds, DAOs, treasuries | Deposit USDC into the credit vault; earn yield from utilization |
| Traders | Pros, quants, algos, later AI agents | Receive a Credit Account, not unrestricted USDC |
| Kredxo | Underwriting + risk + enforcement | Score, capacity, leverage, markets, limits, pricing, tighten/loosen |

## Capital flow

```
LPs deposit USDC → Credit Vault → Underwriting → Trader Credit Account → Trading
                                                              ↓
                                                    Profit / Loss
                                                         ↓
                                              Trader  |  LP + protocol
```

Hackathon liquidity may be testnet USDC, simulated LP deposits, and seeded volume. The economic mechanism must still work onchain.

## Onchain vs offchain

**Onchain:** LP deposits/withdrawals, credit allocation, credit account, trading permissions, risk policies, trade execution, position state, utilization, repayment, interest, PnL, policy changes, events.

**Offchain:** historical processing, scoring, Sharpe/Sortino/drawdown, volatility/liquidity/correlation, risk modelling, simulation, credit recommendation.

```
Monad → RPC / Indexer → Python pipeline → PostgreSQL
    → Risk Engine → Credit Engine → Policy Engine → signed policy → Monad
```

Python decides. Solidity enforces.

## Contract map

Do not implement all six on day one. Order: Registry → Vault → TradingAccount, then RiskPolicy, RiskController, Settlement.

| Contract | Role |
|---|---|
| `KredxoRegistry` | Users, markets, risk controllers, vaults, approved venues |
| `KredxoCreditVault` | LP capital, TVL, shares, allocated vs utilized credit, interest |
| `KredxoTradingAccount` | Hold credit, execute approved trades, track exposure, block unauthorized withdrawal |
| `KredxoRiskPolicy` | Current trading authority (limits, leverage, markets, loss) |
| `KredxoRiskController` | Authorized policy updates from the offchain engine |
| `KredxoSettlement` | PnL, repayments, interest, losses, account closure (MVP-simple) |

## Accounting

Distinguish **credit capacity** (authorized) from **credit utilization** (drawn). Example: vault TVL $100K, trader A capacity $50K, trader B capacity $20K, actual used $23K.

## Monad

Kredxo needs fast, inexpensive, frequent settlement and risk-policy updates because trading credit is continuously changing. Use current official figures in documentation: **10,000 TPS, 300ms block frequency, 600ms finality**. Do not use older 400ms/800ms figures.

Do not say "we put a lending protocol on Monad."

## MVP loop

```
LP → USDC Vault → Trader → Credit Assessment → Credit Account
  → Trading Policy → Trade → Market Stress → Adaptive Credit Reduction
  → Trade Rejected → Market Recovery → Credit Restored
```

## Stack

- Contracts: Solidity, Foundry, OpenZeppelin, Monad
- Backend: Python, FastAPI, pandas, NumPy, Web3.py, PostgreSQL
- Frontend: Next.js, React, TypeScript, Tailwind, wagmi, viem, ECharts
- Infra: Monad testnet, Vercel, Render, PostgreSQL, Monad RPC
