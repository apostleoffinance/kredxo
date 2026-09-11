"use client";

import { useChainId, useSwitchChain } from "wagmi";

import { MONAD_MAINNET_ID, MONAD_TESTNET_ID } from "@/lib/monad";

export function NetworkSwitch() {
  const chainId = useChainId();
  const { switchChain, isPending, error } = useSwitchChain();
  const err =
    error && "shortMessage" in error && typeof error.shortMessage === "string"
      ? error.shortMessage
      : error?.message;

  return (
    <div className="kx-net">
      <button
        type="button"
        className={chainId === MONAD_TESTNET_ID ? "kx-net-btn is-on" : "kx-net-btn"}
        disabled={isPending}
        onClick={() => switchChain({ chainId: MONAD_TESTNET_ID })}
      >
        Testnet
      </button>
      <button
        type="button"
        className={chainId === MONAD_MAINNET_ID ? "kx-net-btn is-on" : "kx-net-btn"}
        disabled={isPending}
        onClick={() => switchChain({ chainId: MONAD_MAINNET_ID })}
      >
        Mainnet
      </button>
      {err ? <span className="kx-net-err">{err}</span> : null}
    </div>
  );
}
