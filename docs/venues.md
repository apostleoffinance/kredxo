# Venues (Kuru / Perpl)

Confirmed 2026-09-11 from official docs. Circle USDC is not Kuru tUSDC or Perpl collateral. Phase 19 hops on the **Credit Account** via a typed path. Do not `payVenue` Circle USDC to the official Kuru or Perpl routers.

Sources: [Kuru contract addresses](https://docs.kuru.io/contracts/Contract-addresses), [Perpl api-docs](https://github.com/PerplFoundation/api-docs), [Perpl developer overview](https://docs.perpl.xyz/resources/for-developers/overview).

## Kredxo vault (Monad Testnet 10143)

Circle official testnet USDC: `0x534b2f3A21130d7a60830c2Df862319e593943A3`

## Hop (Phase 19)

```
Credit Account (Circle USDC)
  → adapter (typed anyToAnySwap)
  → tUSDC / Perpl USD still on the Credit Account
  → venue action
```

The trader never receives the token. The router does not hold funds. Kuru Flow quote calldata is not used. A missing hop path reverts `KredxoWrongAsset` before the venue is paid.

Live faucet vault is still Internal `executeTrade`. Do not redeploy it to attach a hop.

## Kuru

| | Testnet 10143 | Mainnet 143 |
|---|---|---|
| Router | `0x7EFbE105Ca7415dE98F96622173458ac1c054630` | `0xd651346d7c789536ebf06dc72aE3C8502cd695CC` |
| USDC | `0x3bA3d39AFcf8bb994f7964B3e0171Ea2Ba361570` | `0x754704Bc059F8C67012fEd69BC8A327a5aafb603` |
| MON-USDC | `0xa241896A7Dbe8a550D2E5fF7A914bB1989ceD2D9` | — |

Swap ABI: `Router.anyToAnySwap(markets, isBuy, nativeSend, debitToken, creditToken, amount, minAmountOut)`.

## Perpl

| | Testnet 10143 | Mainnet 143 |
|---|---|---|
| Exchange | `0x1964C32f0bE608E7D29302AFF5E61268E72080cc` | `0x34B6552d57a35a1D042CcAe1951BD1C370112a6F` |
| Collateral | USD `0xdF5B718d8FcC173335185a2a1513eE8151e3c027` / aUSD `0xa9012a055bd4e0eDfF8Ce09f960291C09D5322dC` | AUSD `0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a` |
| API | `https://testnet.perpl.xyz/api` | `https://app.perpl.xyz/api` |

## Switch

Live Kredxo is testnet **10143**. Mainnet **143** venue addresses are recorded for later. Do not call 143 from the 10143 vault. Aave is not in this phase.
