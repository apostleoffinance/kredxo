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


def _forge(*args: str) -> subprocess.CompletedProcess[str]:
    forge = shutil.which("forge")
    assert forge, "forge must be on PATH for the Phase 13 invariant"
    env = os.environ.copy()
    env["FOUNDRY_ETH_RPC_URL"] = ""
    return subprocess.run(
        [forge, "test", "--offline", *args],
        cwd=ROOT / "contracts",
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_python_never_allows_size_over_btc_cap():
    session = SessionLocal()
    seed_wallet(session, DEMO)
    sitting = simulate_stress(session, DEMO)
    session.close()

    for stage in sitting["stages"].values():
        cap = stage["policy"]["markets"]["BTC"]
        lev = stage["policy"]["maxLeverage"]
        assert _allows(stage, cap, lev)
        assert not _allows(stage, cap + 1, lev)
        assert not _allows(stage, cap + 20_000, 1)
        assert not _allows(stage, min(cap, 1), lev + 0.1)


def test_credit_and_risk_loop_still_fail_closed():
    session = SessionLocal()
    seed_wallet(session, DEMO)
    session.close()

    sitting = client.post("/stress/simulate", json={"wallet": DEMO}).json()
    assert sitting["trade"]["allowed_before"] is True
    assert sitting["trade"]["allowed_after_shock"] is False
    assert sitting["trade"]["allowed_after_recovery"] is True
    assert sitting["stages"]["shock"]["policy"]["markets"]["BTC"] < sitting["trade"]["size"]


def test_foundry_invariant_fail_closed():
    result = _forge("--match-contract", "InvariantTest")
    assert result.returncode == 0, result.stdout + result.stderr
    fail_closed = _forge("--match-contract", "FailClosedTest")
    assert fail_closed.returncode == 0, fail_closed.stdout + fail_closed.stderr
