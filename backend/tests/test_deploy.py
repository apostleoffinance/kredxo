import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_foundry_deploy_wires_phase15_stack():
    forge = shutil.which("forge")
    assert forge, "forge must be on PATH for the Phase 15 deploy test"
    env = os.environ.copy()
    env["FOUNDRY_ETH_RPC_URL"] = ""
    result = subprocess.run(
        [forge, "test", "--offline", "--match-contract", "DeployTest"],
        cwd=ROOT / "contracts",
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
