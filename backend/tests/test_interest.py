from decimal import Decimal

from fastapi.testclient import TestClient

from app.interest import borrow_apr
from app.main import app

client = TestClient(app)


def test_low_idle_apr_is_7_2_percent():
    assert borrow_apr("LOW", Decimal("0")) == Decimal("0.072")


def test_normal_idle_apr_is_8_percent():
    assert borrow_apr("NORMAL", Decimal("0")) == Decimal("0.08")


def test_high_half_util_apr_is_14_5_percent():
    assert borrow_apr("HIGH", Decimal("0.5")) == Decimal("0.145")


def test_high_util_band_reaches_14_8_percent():
    assert borrow_apr("HIGH", Decimal("0.56")) == Decimal("0.148")


def test_markets_exposes_apr_band():
    body = client.get("/api/markets").json()
    assert Decimal(body["base_apr"]) == Decimal("0.08")
    assert Decimal(body["apr"]["low"]) == Decimal("0.072")
    assert Decimal(body["apr"]["normal"]) == Decimal("0.08")
    assert Decimal(body["apr"]["high"]) == Decimal("0.145")
