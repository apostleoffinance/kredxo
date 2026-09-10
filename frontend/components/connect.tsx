"use client";

import { useAccount, useConnect, useDisconnect } from "wagmi";

import { compact } from "@/lib/format";

export function ConnectButton() {
  const { address, isConnected } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();

  if (isConnected && address) {
    return (
      <button type="button" className="kx-btn" onClick={() => disconnect()}>
        {compact(address)}
      </button>
    );
  }

  return (
    <button
      type="button"
      className="kx-btn kx-btn-primary"
      disabled={isPending}
      onClick={() => connect({ connector: connectors[0] })}
    >
      {isPending ? "Connecting…" : "Connect"}
    </button>
  );
}
