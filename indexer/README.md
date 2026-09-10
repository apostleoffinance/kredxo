# Indexer

Monad RPC → PostgreSQL trade pipeline.

```bash
# from repo root, with backend venv + PYTHONPATH
source backend/.venv/bin/activate
export PYTHONPATH=backend

python -m indexer.main check
python -m indexer.main seed
python -m indexer.main sync
```

`seed` writes 120 deterministic historical trades for `DEMO_WALLET` (`0x8300…09A2`). That is the Phase 5 proof path until the trading account is deployed.

`sync` pulls `TradeApproved` / `PositionClosed` logs when `TRADING_ACCOUNT_ADDRESS` is set.
