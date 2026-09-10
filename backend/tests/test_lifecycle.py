import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "backend"))

from fastapi.testclient import TestClient

from app.db import SessionLocal
from app.main import app
from app.risk.engine import shocked_market
from app.services.lifecycle import write_lifecycle_fixture
from indexer.seed import seed_wallet

client = TestClient(app)
DEMO = "0x83000000000000000000000000000000000009A2"
FIXTURE = ROOT / "contracts" / "testdata" / "lifecycle.json"
SHOCK = {
    "volatility": float(shocked_market().volatility),
    "liquidity": float(shocked_market().liquidity),
    "price_move": float(shocked_market().price_move),
    "correlation": float(shocked_market().correlation),
    "funding": float(shocked_market().funding),
}


def _seed() -> None:
    session = SessionLocal()
    seed_wallet(session, DEMO)
    session.close()


def test_credit_request_runs_full_pipeline():
    _seed()
    body = client.post("/credit/request", json={"wallet": DEMO}).json()
    assert body["score"] == 87
    assert body["tier"] == "ADVANCED"
    assert body["policy"]["riskLevel"] == body["risk"]["risk_level"]
    assert body["onchain"]["creditLimit"] == body["policy"]["creditLimit"] * 1_000_000
    assert body["onchain_flat"]["btcLimit"] > 0


def test_python_policy_enforced_onchain():
    _seed()
    normal = client.post("/credit/request", json={"wallet": DEMO}).json()
    shock = client.post("/credit/request", json={"wallet": DEMO, "market": SHOCK}).json()

    assert shock["onchain_flat"]["creditLimit"] < normal["onchain_flat"]["creditLimit"]
    assert shock["onchain_flat"]["btcLimit"] < normal["onchain_flat"]["btcLimit"]
    assert shock["onchain_flat"]["riskLevel"] > normal["onchain_flat"]["riskLevel"]

    payload = write_lifecycle_fixture(FIXTURE, normal, shock)
    assert payload["tradeSize"] <= payload["normal"]["btcLimit"]
    assert payload["tradeSize"] > payload["shock"]["btcLimit"]
    assert json.loads(FIXTURE.read_text())["score"] == 87

    forge = shutil.which("forge")
    assert forge, "forge must be on PATH for the Phase 9 integration test"
    env = os.environ.copy()
    env["FOUNDRY_ETH_RPC_URL"] = ""
    result = subprocess.run(
        [forge, "test", "--offline", "--match-contract", "LifecycleTest"],
        cwd=ROOT / "contracts",
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
