"use client";

import { useAccount } from "wagmi";

import { DEMO_WALLET } from "./config";

export function useViewWallet() {
  const { address, isConnected } = useAccount();
  const wallet = (address ?? DEMO_WALLET) as `0x${string}`;
  return {
    wallet,
    isDemo: !isConnected,
    isConnected,
    connected: address,
  };
}
