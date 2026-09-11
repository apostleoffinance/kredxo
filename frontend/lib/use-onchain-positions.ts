"use client";

import { useMemo } from "react";
import { useChainId, useReadContract, useReadContracts } from "wagmi";

import { accountAbi } from "./abi";
import { MARKET_ADDR } from "./config";
import { units6 } from "./format";
import { kredxoOn } from "./networks";

export type OnchainPosition = {
  id: number;
  market: `0x${string}`;
  symbol: string;
  side: number;
  size: number;
  entryPrice: number;
  leverage: number;
  margin: number;
  open: boolean;
};

function marketSymbol(addr: string) {
  const lower = addr.toLowerCase();
  if (lower === MARKET_ADDR.BTC.toLowerCase()) return "BTC";
  if (lower === MARKET_ADDR.ETH.toLowerCase()) return "ETH";
  return "MKT";
}

export function useOnchainPositions(enabled: boolean) {
  const chainId = useChainId();
  const account = kredxoOn(chainId).tradingAccount;
  const countQ = useReadContract({
    address: account || undefined,
    abi: accountAbi,
    functionName: "positionCount",
    query: { enabled: Boolean(account && enabled) },
  });
  const count = countQ.data !== undefined ? Number(countQ.data) : 0;
  const ids = useMemo(() => Array.from({ length: count }, (_, i) => i + 1), [count]);
  const rows = useReadContracts({
    query: { enabled: Boolean(account && enabled && count > 0) },
    contracts: account
      ? ids.map((id) => ({
          address: account,
          abi: accountAbi,
          functionName: "positions" as const,
          args: [BigInt(id)] as const,
        }))
      : [],
  });

  const positions: OnchainPosition[] = [];
  rows.data?.forEach((row, i) => {
    const raw = row.result;
    if (!raw) return;
    const [market, side, size, entryPrice, leverage, margin, , open] = raw;
    positions.push({
      id: ids[i],
      market,
      symbol: marketSymbol(market),
      side: Number(side),
      size: units6(size) ?? 0,
      entryPrice: Number(entryPrice) / 1e18,
      leverage: Number(leverage) / 1e18,
      margin: units6(margin) ?? 0,
      open,
    });
  });

  return {
    count,
    positions,
    open: positions.filter((p) => p.open),
    refetch: async () => {
      await countQ.refetch();
      await rows.refetch();
    },
  };
}
