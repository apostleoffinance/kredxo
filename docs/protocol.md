# Protocol

## Actors

- **LP** — supplies USDC, receives LP shares
- **Trader** — has trading history, receives credit capacity, trades through a Credit Account
- **Kredxo Risk Engine** (offchain) — score, risk, policy proposal
- **Kredxo Protocol** (onchain) — holds capital, enforces policy, executes trades, handles repayment

## Master lifecycle

1. LP deposits USDC into the Credit Vault
2. Trader requests credit
3. Kredxo analyzes trading history
4. Credit Score → Base Credit
5. Market + trader risk → Current Credit
6. Credit Policy created; Credit Account activated
7. Trader executes trades; PnL changes
8. Risk changes → policy changes → credit changes
9. Trader repays; LP receives yield

## Vault

Minimum interface: `deposit(assets)`, `withdraw(shares)`, `allocateCredit(trader, amount)`, `releaseCredit(trader, amount)`, `repay(trader, amount)`.

Tracks: `totalAssets`, `totalShares`, `availableLiquidity`, `allocatedCredit`, `utilizedCredit`.

- `totalAssets` = idle USDC + outstanding draws
- `availableLiquidity` = `totalAssets - allocatedCredit` (unreserved; withdrawable)
- `allocateCredit` reserves capacity and does **not** transfer USDC
- `utilizeCredit` draws USDC to a receiver (Phase 3: the trading account)
- `repay` returns USDC and reduces utilization

Committed credit is not utilization. A $50K capacity with $0 drawn is valid. LPs cannot withdraw reserved capacity.

## Credit Account

The trader does not withdraw credit as unrestricted USDC. The account is programmable financial authority.

Once `vault.setTradingAccount` binds a trader, `utilizeCredit` may only send USDC to that account. `draw` pulls reserved vault credit into the account. `withdraw` / `withdrawCollateral` always revert. Leverage is WAD (`1e18 = 1x`). Position storage exists; open/close is Phase 4.

```
struct CreditAccount {
    address trader;
    uint256 creditLimit;
    uint256 usedCredit;
    uint256 collateral;
    uint256 maxLeverage;
    uint256 dailyLossLimit;
    bool active;
}

struct Position {
    address market;
    uint256 size;
    uint256 entryPrice;
    int256 pnl;
}
```

Example authority: BTC/ETH allowed, max leverage 5x, per-market caps, daily loss cap, withdrawals disabled.

## Trade execution

One simplified Monad-native venue for MVP.

Request: market, side, size, leverage.

`executeTrade(market, side, size, leverage, price)` on `KredxoTradingAccount` is the single MVP venue. `size` is USDC notional; margin = `size * 1e18 / leverage`.

Onchain checks (all required): account active, market allowed, credit/idle USDC available, leverage allowed, position limit, daily loss limit.

Failures emit `TradeRejected(trader, reason)` and revert `KredxoTradeRejected(reason)`. Example: BTC limit $15K, requested $25K → reason `exposure exceeds position limit`.

`closePosition` realizes PnL; losses transfer USDC to the vault and count toward the daily loss cap.

Phase 18 adds a policy-controlled router in front of approved Monad venues. Adapter 0 remains this internal book. First external venues: Perpl (perps), then Kuru (spot). Aave supply is later. The Credit Account stays the actor; the router does not hold funds and must not execute arbitrary calldata. Phase 19 hops Circle USDC to the venue token on the Credit Account via a typed `anyToAnySwap` path. Official Kuru/Perpl testnet tokens are not Circle USDC; see `docs/venues.md`.

## Risk policy

```
struct RiskPolicy {
    uint256 creditLimit;
    uint256 maxLeverage;
    uint256 dailyLossLimit;
    uint256 validFrom;
    uint256 validUntil;
    uint8 riskLevel;
    bool active;
}
```

Per-trader per-market `positionLimits`. Only `RISK_CONTROLLER_ROLE` may update. Stale or expired policy cannot authorize trades.

## Events

```
CreditIssued(trader, amount)
CreditAdjusted(trader, oldCredit, newCredit)
PolicyUpdated(trader, creditLimit, leverageLimit)
TradeApproved(trader, market, size)
TradeRejected(trader, reason)
RiskLevelChanged(trader, oldLevel, newLevel)
RepaymentMade(trader, amount)
```

## Interest (Phase 10)

`Borrow APR = Base Rate (8%) + Risk Premium + Utilization Premium`

Trader pays interest → vault → LP yield. Keep accounting simple for the hackathon.

## Losses (V1)

Losses reduce available equity, raise risk, lower credit. Breach of safety threshold triggers position reduction. No institutional liquidation engine.

## Deployment order

Registry → Credit Vault → Risk Policy → Risk Controller → Trading Account → Settlement. Then configure USDC, controller, vault, venue, markets.

## Invariant

A trader must never execute more risk than the currently active policy permits.
