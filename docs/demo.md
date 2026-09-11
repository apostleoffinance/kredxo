# 3-minute technical demo

Open `http://localhost:3000/demo`. Unconnected sessions read the seeded trader `0x8300…09A2`.

There are two number sets. Do not mix them.

| Layer | What judges see | Why |
|---|---|---|
| Python | Score 87 / ADVANCED / $50k base | Underwriting from 120 trades |
| Onchain (this faucet seed) | $20 vault, $20 credit, $10 BTC cap | Issued credit never exceeds LP deposit |

The **canonical** sitting (Foundry `LifecycleTest` + `StressTest`) is $100k LP → $50k credit → $10k BTC approved → shock → $20k BTC rejected → recover. Run that anytime with `scripts/ci.sh`.

The **live Monad Testnet** seed used Circle faucet USDC (~20). Same mechanism, scaled to inventory.

## Minute 0:00 — Product

Kredxo is adaptive trading credit. LPs fund the vault. The trader gets a Credit Account, not USDC in their wallet. Python decides. Solidity enforces.

Show Market: TVL, allocated, utilized. Explorer: vault [`0xd5dF…7ddc`](https://testnet.monadvision.com/address/0xd5dF1Ba644019cf646f932F0c2FE740196517ddc).

## Minute 0:30 — History → score

Profile: 120 trades, ~$1.8M volume, +$83,420 PnL, 8.7% max DD, 0 liquidations. Score **87 / ADVANCED**. Request credit if you want the JSON; the score is already computed.

Say: Python *recommends* $50k. The vault only has $20, so onchain capacity is $20. That is vault solvency, not trader collateral.

## Minute 1:00 — Credit Account

Account: onchain `creditLimit` / used / available. Withdrawals are disabled in the contract. Policy: BTC and ETH, leverage cap, daily loss.

Credit issued tx: [`allocateCredit`](https://testnet.monadvision.com/tx/0x0f9421da8e477bcd14d2aca288fef146813ad5387f98c0d225a9334e06e3cd9a).

## Minute 1:20 — Approve a trade

Trade. Size defaults to 40% of the live BTC cap (about **$4** on the faucet seed). Connect the **trader or operator** key. Execute. The UI preview can fail; the contract is still the authority.

Canonical story: $10k BTC approved. Live faucet: a size under $10 BTC approved.

## Minute 1:50 — Stress → reject

Risk Center → **SIMULATE MARKET STRESS**.

Python injects vol +85%, liquidity −28%, drawdown −12%, correlation +20%. Controller `applyPolicy` writes HIGH. Then the sitting probes a $20k BTC trade (canonical over-limit). On this faucet book that size is over-limit even before shock — still a **real onchain revert**. Foundry proves the full $50k → $32k → $20k reject path.

Say the revert out loud. Rejection is in the account, not the frontend.

## Minute 2:20 — Recover

**Recover → ELEVATED**, then **Recover → NORMAL**. Credit and BTC caps step back up. Monad 300ms blocks / 600ms finality is why policy can move with the market.

## Minute 2:40 — Close

Kredxo is not the market. It is the credit and risk layer: who gets capital, how much, what they may do, when that changes. Today’s venue is the first adapter. Next: Perpl (perps), then Kuru (spot). Aave later. Credit still never leaves the account.

## Operator key

The deployer (`0xcEca…0f6D`) is LP + admin + controller. **Do not paste `PRIVATE_KEY` into slides or git.** Judges can run the Python sitting and Foundry tests without it. Onchain `applyPolicy` / `executeTrade` need that key or a granted operator.
