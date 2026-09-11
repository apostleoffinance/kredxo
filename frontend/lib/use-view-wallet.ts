"use client";

import { useAccount } from "wagmi";

import { DEMO_WALLET } from "./config";

export function useViewWallet(opts?: { sitting?: boolean }) {
  const { address, isConnected } = useAccount();
  if (opts?.sitting) {
    return {
      wallet: (address ?? DEMO_WALLET) as `0x${string}`,
      isDemo: !isConnected,
      isConnected,
      connected: address,
    };
  }
  return {
    wallet: address as `0x${string}` | undefined,
    isDemo: false,
    isConnected,
    connected: address,
  };
}
