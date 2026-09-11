# Kredxo agent instructions

Read these before writing any code:

1. `docs/CURRENT_PHASE.md` — what to work on now
2. `docs/phase-gates.md` — completion checklist; do not skip phases
3. `docs/architecture.md` — product loop and onchain/offchain split
4. `docs/protocol.md`, `docs/credit-model.md`, `docs/risk-model.md`, `docs/api-and-data.md`, `docs/venues.md`
5. `.cursor/rules/` — always-on product, architecture, scope, and phase-gate rules

Principle: **Python decides. Solidity enforces.**

Build the financial mechanism first. Do not start the next phase until every checkbox in the current phase is true.

Phase 19 complete: Circle USDC hops to the venue token on the Credit Account. Aave is not in this phase.
