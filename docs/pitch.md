# 2-minute pitch

**Kredxo turns trading history into adaptive onchain credit.**

Kredxo is Monad-native adaptive credit infrastructure for onchain markets. LPs fund a USDC credit vault. Proven traders and strategies receive a **Credit Account** — programmable trading authority, not unrestricted USDC.

## The problem

Onchain markets still treat capital as a transfer. If you send a trader USDC, you lose control of risk. If you only score them, nothing stops the next trade.

## What Kredxo does

```
Credit Intelligence → Adaptive Risk → Programmable Policy → Execution → Reassessment
```

Python underwrites. Solidity enforces. A trader must never execute more risk than the live onchain policy. Rejection happens in the contract, not the UI.

Traders get **capital access without capital custody.** Issued credit cannot be withdrawn. It can only be used inside the policy: markets, leverage, position caps, daily loss.

## The sitting (2 minutes)

1. LP deposits USDC into the Credit Vault.
2. A wallet with 120 trades scores **87 / ADVANCED**. Python recommends **$50k**.
3. Credit is issued onchain (`CreditIssued`). Capacity never exceeds vault deposits.
4. A BTC trade inside the policy is approved.
5. Market stress hits. The risk engine tightens credit, leverage, and BTC caps.
6. The same style of trade is **rejected onchain**.
7. Markets recover. Credit and policy restore.

Monad makes that loop real: **10,000 TPS, 300ms blocks, 600ms finality** — fast enough to rewrite policy and enforce it on the next trade.

## What this is not

Not a collateral lending protocol. Not a credit-score dashboard. Not a trading bot. Not “a lending protocol on Monad.”

The first execution venue is Kredxo’s own Monad BTC/ETH book — a reference adapter so the credit loop is a real transaction. Next: a **Monad-native, policy-controlled venue router** — **Perpl** (perps) then **Kuru** (spot). Aave supply comes after. Same account. Still no withdrawal.

## One line to leave with

Python decides. Solidity enforces. Kredxo turns trading history into credit that can change as fast as the market.
