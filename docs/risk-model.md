# Risk model

Adaptive Risk answers: **how much risk should we allow this trader to take right now?**

The credit score alone is not enough. Base credit is the ceiling; current credit is adaptive.

## Formula

```
Current Credit = Base Credit × Trader Risk Multiplier × Market Risk Multiplier
```

Example: `$50,000 × 0.90 × 0.80 = $36,000`

## Inputs

| Trader risk | Market risk | Account risk |
|---|---|---|
| credit score, drawdown, leverage, PnL, concentration, liquidations | volatility, liquidity, price movement, funding, correlation | exposure, utilization, unrealized PnL, margin, distance to liquidation |

## Risk states

`LOW` → `NORMAL` → `ELEVATED` → `HIGH` → `CRITICAL`

## Policy output (Python → Solidity)

```json
{
  "creditLimit": 36000,
  "maxLeverage": 3.5,
  "dailyLossLimit": 1500,
  "markets": { "BTC": 15000, "ETH": 10000 },
  "riskLevel": "HIGH"
}
```

## Stress simulation (demo)

Before: NORMAL, $50K credit, 5x, $25K BTC, $2K daily loss.

Inject: BTC vol +85%, liquidity -28%, BTC drawdown -12%, correlation +20%.

After: HIGH, $32K credit, 3x, $12K BTC, $1K daily loss.

Then a $20K BTC trade that previously worked **reverts**. Recovery: HIGH → ELEVATED → NORMAL and credit $32K → $41K → $50K.

## Pricing

`Borrow APR = 8% + risk premium + utilization premium` (e.g. low ~7.2–8%, high ~14.5–14.8%).

## Tests

- High volatility → lower credit
- Low liquidity → lower credit
- Higher concentration / drawdown → tighter policy
