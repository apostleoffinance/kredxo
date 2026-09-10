import os
import shutil
import subprocess
import sys
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "backend"))

from fastapi.testclient import TestClient

from app.db import SessionLocal
from app.main import app
from app.risk.engine import HEALTHY_TRADER, evaluate_risk, recovering_market, shocked_market
from app.services.stress import write_stress_fixture
from indexer.seed import seed_wallet

client = TestClient(app)
DEMO = "0x83000000000000000000000000000000000009A2"
FIXTURE = ROOT / "contracts" / "testdata" / "stress.json"


def test_recovery_path_is_high_then_elevated_then_normal():
    high = evaluate_risk("0x1", Decimal("50000"), HEALTHY_TRADER, shocked_market())
    mid = evaluate_risk("0x1", Decimal("50000"), HEALTHY_TRADER, recovering_market())
    calm = evaluate_risk("0x1", Decimal("50000"), HEALTHY_TRADER)
    assert high.risk_level == "HIGH"
    assert high.current_credit == Decimal("32000")
    assert mid.risk_level == "ELEVATED"
    assert mid.current_credit == Decimal("41000")
    assert calm.risk_level == "NORMAL"
    assert calm.current_credit == Decimal("50000")
    assert high.current_credit < mid.current_credit < calm.current_credit


def test_simulate_sitting_then_onchain_enforcement():
    session = SessionLocal()
    seed_wallet(session, DEMO)
    session.close()

    sitting = client.post("/stress/simulate", json={"wallet": DEMO}).json()
    stages = sitting["stages"]
    assert sitting["injection"]["volatility"] == "+85%"
    assert stages["shock"]["risk_level"] == "HIGH"
    assert stages["elevated"]["risk_level"] == "ELEVATED"
    assert stages["recovered"]["risk_level"] == "NORMAL"
    assert Decimal(stages["shock"]["current_credit"]) < Decimal(stages["elevated"]["current_credit"])
    assert Decimal(stages["elevated"]["current_credit"]) < Decimal(stages["recovered"]["current_credit"])
    assert sitting["trade"]["allowed_before"] is True
    assert sitting["trade"]["allowed_after_shock"] is False
    assert sitting["trade"]["allowed_after_recovery"] is True

    write_stress_fixture(FIXTURE, sitting)
    forge = shutil.which("forge")
    assert forge, "forge must be on PATH for the Phase 12 sitting"
    env = os.environ.copy()
    env["FOUNDRY_ETH_RPC_URL"] = ""
    result = subprocess.run(
        [forge, "test", "--offline", "--match-contract", "StressTest"],
        cwd=ROOT / "contracts",
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
