# Kredxo backend

FastAPI credit/risk intelligence. **Python decides. Solidity enforces.**

Phase 1: config, Postgres engine, `/health` (Monad RPC + optional DB ping). No scoring or policy yet.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp ../.env.example ../.env
uvicorn app.main:app --reload --port 8000
```

Postgres (host port **15432**, required from Phase 5):

```bash
docker compose up -d postgres
```
