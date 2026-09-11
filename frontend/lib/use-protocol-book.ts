"use client";

import { useChainId, useReadContract } from "wagmi";

import { policyAbi, vaultAbi } from "./abi";
import { DEMO_WALLET } from "./config";
import { riskLevelName, units6 } from "./format";
import { kredxoOn } from "./networks";

export function useProtocolBook() {
  const chainId = useChainId();
  const kredxo = kredxoOn(chainId);
  const vault = kredxo.vault;
  const policy = kredxo.riskPolicy;
  const on = Boolean(vault);
  const live = { enabled: on, refetchInterval: 8_000 as const };

  const tvlQ = useReadContract({
    address: vault || undefined,
    abi: vaultAbi,
    functionName: "totalAssets",
    query: live,
  });
  const allocatedQ = useReadContract({
    address: vault || undefined,
    abi: vaultAbi,
    functionName: "allocatedCredit",
    query: live,
  });
  const utilizedQ = useReadContract({
    address: vault || undefined,
    abi: vaultAbi,
    functionName: "utilizedCredit",
    query: live,
  });
  const availableQ = useReadContract({
    address: vault || undefined,
    abi: vaultAbi,
    functionName: "availableLiquidity",
    query: live,
  });
  const supplyQ = useReadContract({
    address: vault || undefined,
    abi: vaultAbi,
    functionName: "totalSupply",
    query: live,
  });
  const sitting = useReadContract({
    address: policy || undefined,
    abi: policyAbi,
    functionName: "policyOf",
    args: [DEMO_WALLET],
    query: { enabled: Boolean(policy), refetchInterval: 8_000 },
  });

  const tvl = units6(tvlQ.data) ?? 0;
  const allocated = units6(allocatedQ.data) ?? 0;
  const utilized = units6(utilizedQ.data) ?? 0;
  const available = units6(availableQ.data) ?? Math.max(tvl - allocated, 0);
  const supplyShares = supplyQ.data;
  const riskLevel = sitting.data ? riskLevelName(sitting.data.riskLevel) : "—";
  const utilPct = tvl > 0 ? utilized / tvl : 0;

  return {
    chainId,
    kredxo,
    vaultOn: on,
    tvl,
    allocated,
    utilized,
    available,
    supplyShares,
    utilPct,
    riskLevel,
    refetch: async () => {
      await Promise.all([
        tvlQ.refetch(),
        allocatedQ.refetch(),
        utilizedQ.refetch(),
        availableQ.refetch(),
        supplyQ.refetch(),
        sitting.refetch(),
      ]);
    },
  };
}
