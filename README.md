# Kredxo

**Adaptive Credit Infrastructure for Onchain Markets**

Kredxo turns trading history into adaptive onchain credit.

Kredxo is a Monad-native adaptive trading-credit market: liquidity providers fund credit for proven traders and strategies, while Kredxo converts verifiable trading history and real-time market risk into dynamic credit capacity and programmable trading authority.

## Mental model

Credit Intelligence → Adaptive Risk → Programmable Policy → Execution → Reassessment

## Architecture principle

Python decides. Solidity enforces.

## Status

Phase 17 complete — demo + submission. **Phase 19 complete:** venue FX hop (Circle USDC → Kuru/Perpl token on the Credit Account). Live vault remains Internal on Monad Testnet. [Submission](docs/submission.md) · [Pitch](docs/pitch.md) · [Demo](docs/demo.md) · [Current phase](docs/CURRENT_PHASE.md).

## Repo

```
kredxo/
├── contracts/     # Foundry — onchain financial infrastructure
├── backend/       # FastAPI — credit + risk intelligence
├── frontend/      # Next.js — financial terminal UI
├── indexer/
├── scripts/
└── docs/
```

```bash
cp .env.example .env
```

## Docs

- [Submission](docs/submission.md)
- [Pitch](docs/pitch.md)
- [Demo script](docs/demo.md)
- [Architecture](docs/architecture.md)
- [Protocol](docs/protocol.md)
- [Credit model](docs/credit-model.md)
- [Risk model](docs/risk-model.md)
- [Phase gates](docs/phase-gates.md)
- [Current phase](docs/CURRENT_PHASE.md)
- [API and data](docs/api-and-data.md)
- [Setup](docs/setup.md)
