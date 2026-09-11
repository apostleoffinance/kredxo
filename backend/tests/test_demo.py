from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_demo_packet():
    response = client.get("/api/demo")
    assert response.status_code == 200
    body = response.json()
    assert body["phase"] == 19
    assert body["product"]["one_liner"].startswith("Kredxo turns trading history")
    assert body["demo_wallet"].lower().endswith("09a2")
    assert body["network"]["chain_id"] == 10143
    assert body["network"]["block_frequency_ms"] == 300
    assert body["sitting"]["canonical"]["base_credit"] == 50_000
    assert body["sitting"]["live"]["onchain_credit"] == 20
    assert body["contracts"]["vault"]
    assert body["seed"]["txs"]["allocateCredit"].startswith("0x")
    assert body["venues"]["first"] == "perpl"
    assert body["venues"]["second"] == "kuru"
    assert body["venues"]["pay_venue"].startswith("hop Circle USDC")
    assert body["venues"]["testnet"]["kuru_usdc_match"] is False
    assert body["venues"]["testnet"]["perpl_collateral_match"] is False
    assert body["venues"]["testnet"]["vault_usdc"].lower().endswith("43a3")
