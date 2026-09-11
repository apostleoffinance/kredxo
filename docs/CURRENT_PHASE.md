# Current phase

**Active:** Complete — Phase 19 venue FX hop (Circle USDC → venue token)

**Last completed:** Phase 19 — Venue hop (2026-09-11)

Phase 17 sitting stays live on Monad Testnet. Do not redeploy that vault. Do not re-seed.

## Now

The execution router hops Circle USDC to the venue token **on the Credit Account** via a typed Kuru `anyToAnySwap` path. The trader never holds the dollars. The router does not hold funds and does not execute Kuru Flow calldata. Official Kuru/Perpl routers are not `payVenue` targets for Circle USDC. Proof: `FOUNDRY_ETH_RPC_URL= forge test --offline --match-contract ExecutionRouterTest`. Live testnet account still uses `executeTrade` until a new account + router is bound.

## Next

Bind a hop path on a new account (not the sitting vault) only after a real Kuru route from Circle `0x534b…` to Kuru tUSDC `0x3bA3…` is confirmed. Aave V3 **supply only** (later). Do not call mainnet 143 from the 10143 vault.
