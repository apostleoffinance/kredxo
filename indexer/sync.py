from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy.orm import Session

from app.services.trades import list_trades, upsert_trade
from indexer.rpc import get_block_number, get_block_timestamp, get_logs

TRADE_APPROVED = "0xfe6079e5af86d4f65934f8b776a5ab0c2183b3470972f0d6817e0f029f6e7e87"
POSITION_CLOSED = "0x03889ec414d60aad079a991887429a3a7acef381d59eef9ee26ec5cec26279ee"


def _addr_from_topic(topic: str) -> str:
    return "0x" + topic[-40:]


def _uint256(data: str, word: int) -> int:
    start = 2 + word * 64
    return int(data[start : start + 64], 16)


def _int256(data: str, word: int) -> int:
    value = _uint256(data, word)
    if value >= 2**255:
        value -= 2**256
    return value


def _address_word(data: str, word: int) -> str:
    return "0x" + data[2 + word * 64 + 24 : 2 + (word + 1) * 64]


def sync_logs(
    session: Session,
    *,
    rpc_url: str,
    account: str,
    from_block: int,
) -> int:
    latest = get_block_number(rpc_url)
    if from_block > latest:
        return 0

    logs = get_logs(
        rpc_url,
        account,
        from_block,
        latest,
        [TRADE_APPROVED, POSITION_CLOSED],
    )
    written = 0
    timestamps: dict[str, datetime] = {}

    for log in logs:
        block_hex = log["blockNumber"]
        if block_hex not in timestamps:
            timestamps[block_hex] = datetime.fromtimestamp(
                get_block_timestamp(rpc_url, block_hex), tz=UTC
            )
        topic = log["topics"][0]
        trader = _addr_from_topic(log["topics"][1])
        tx_hash = log["transactionHash"]
        log_index = int(log["logIndex"], 16)
        ts = timestamps[block_hex]

        if topic.lower() == TRADE_APPROVED.lower():
            market = _address_word(log["data"], 0)
            size = Decimal(_uint256(log["data"], 1)) / Decimal(1_000_000)
            upsert_trade(
                session,
                wallet=trader,
                market=market,
                side="LONG",
                size=size,
                leverage=Decimal("1"),
                timestamp=ts,
                tx_hash=tx_hash,
                log_index=log_index,
            )
            written += 1
        elif topic.lower() == POSITION_CLOSED.lower():
            pnl = Decimal(_int256(log["data"], 0)) / Decimal(1_000_000)
            open_trades = [t for t in list_trades(session, trader) if t.pnl is None]
            if open_trades:
                target = open_trades[-1]
                target.pnl = pnl
                target.exit_price = target.entry_price
            else:
                upsert_trade(
                    session,
                    wallet=trader,
                    market="unknown",
                    side="CLOSE",
                    size=Decimal("0"),
                    leverage=Decimal("1"),
                    timestamp=ts,
                    tx_hash=tx_hash,
                    log_index=log_index,
                    pnl=pnl,
                )
            written += 1

    session.commit()
    return written
