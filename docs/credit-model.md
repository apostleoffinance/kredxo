# Credit model

Credit Intelligence answers: **should Kredxo give this trader credit, and how much base capacity?**

## Inputs

From indexed trading history: trades, positions, PnL, volume, entry/exit, leverage, liquidations, drawdown, holding period.

## Metrics

| Bucket | Metrics |
|---|---|
| Performance | realized PnL, return, win rate |
| Risk-adjusted | Sharpe, Sortino |
| Risk behavior | max drawdown, leverage, liquidations, concentration, volatility exposure |
| Consistency | frequency, return consistency, behavior in volatile markets |

## Score

Deterministic and auditable. Not "real financial standards" — demonstrates underwriting.

```
Score =
  Performance      × 25%
+ Risk Adjusted    × 20%
+ Drawdown         × 20%
+ Leverage         × 15%
+ Liquidations     × 10%
+ Consistency      × 10%
```

## Tiers → base credit

| Score | Tier | Base credit |
|---|---|---|
| 0–39 | Restricted | $0 |
| 40–59 | Emerging | $5,000 |
| 60–74 | Established | $15,000 |
| 75–89 | Advanced | $50,000 |
| 90–100 | Elite | $100,000+ |

## Demo profile (seed this)

Wallet with 100+ historical trades, ~$1.82M volume, +$83,420 PnL, Sharpe 2.14, max drawdown 8.7%, 0 liquidations → **score 87 / Advanced / $50,000 base credit**.

## Tests

- High Sharpe → higher score
- High drawdown → lower score
- Liquidation → lower score

Score and base credit live in the backend first, then the authorized result is pushed onchain.

`GET /api/credit/{wallet}` and `POST /credit/evaluate` recompute from `trades`. The seeded demo wallet scores **87 / ADVANCED / $50,000**.
