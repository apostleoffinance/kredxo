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
from app.services.stress import _allows, simulate_stress
from indexer.seed import seed_wallet

client = TestClient(app)
DEMO = "0x83000000000000000000000000000000000009A2"


def test_api_cannot_mark_over_limit_trade_allowed():
    session = SessionLocal()
    seed_wallet(session, DEMO)
    sitting = simulate_stress(session, DEMO)
    session.close()

    shock = sitting["stages"]["shock"]
    size = sitting["trade"]["size"]
    assert size > shock["policy"]["markets"]["BTC"]
    assert sitting["trade"]["allowed_after_shock"] is False
    assert not _allows(shock, size, sitting["trade"]["leverage"])


def test_security_suite_enforces_without_frontend():
    forge = shutil.which("forge")
    assert forge, "forge must be on PATH for the Phase 14 security suite"
    env = os.environ.copy()
    env["FOUNDRY_ETH_RPC_URL"] = ""
    result = subprocess.run(
        [forge, "test", "--offline", "--match-contract", "SecurityTest"],
        cwd=ROOT / "contracts",
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
