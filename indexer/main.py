"""Monad RPC → PostgreSQL. Commands: check | seed | sync."""

from __future__ import annotations

import argparse
import sys

from indexer import pathsetup  # noqa: F401 — puts backend on sys.path

from app.config import settings
from app.db import SessionLocal, init_db, ping_database
from indexer.rpc import get_chain_id
from indexer.seed import seed_wallet
from indexer.sync import sync_logs


def cmd_check() -> int:
    live = get_chain_id(settings.monad_rpc_url)
    print(f"rpc={settings.monad_rpc_url}")
    print(f"configured_chain_id={settings.monad_chain_id}")
    print(f"live_chain_id={live}")
    print(f"database_reachable={ping_database()}")
    if live != settings.monad_chain_id:
        print("error: RPC chain id mismatch", file=sys.stderr)
        return 1
    return 0


def cmd_seed(wallet: str) -> int:
    if not ping_database():
        print("error: postgres is not reachable", file=sys.stderr)
        return 1
    init_db()
    session = SessionLocal()
    try:
        count = seed_wallet(session, wallet)
    finally:
        session.close()
    print(f"seeded wallet={wallet.lower()} trades={count}")
    return 0


def cmd_sync() -> int:
    if not settings.trading_account_address:
        print("sync skipped: TRADING_ACCOUNT_ADDRESS is empty (seed history instead)")
        return 0
    if not ping_database():
        print("error: postgres is not reachable", file=sys.stderr)
        return 1
    init_db()
    session = SessionLocal()
    try:
        written = sync_logs(
            session,
            rpc_url=settings.monad_rpc_url,
            account=settings.trading_account_address,
            from_block=settings.indexer_from_block,
        )
    finally:
        session.close()
    print(f"synced logs={written} account={settings.trading_account_address}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Kredxo trade indexer")
    parser.add_argument("command", choices=("check", "seed", "sync"), nargs="?", default="check")
    parser.add_argument("--wallet", default=settings.demo_wallet)
    args = parser.parse_args()
    if args.command == "check":
        return cmd_check()
    if args.command == "seed":
        return cmd_seed(args.wallet)
    return cmd_sync()


if __name__ == "__main__":
    raise SystemExit(main())
