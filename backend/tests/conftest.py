import os

os.environ["DATABASE_URL"] = "sqlite+pysqlite:///:memory:"

from collections.abc import Generator

import pytest

from app.db import SessionLocal, init_db
from app.models.trade import Trade


@pytest.fixture(autouse=True)
def clean_trades() -> Generator[None, None, None]:
    init_db()
    session = SessionLocal()
    session.query(Trade).delete()
    session.commit()
    session.close()
    yield
