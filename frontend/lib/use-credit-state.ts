"use client";

import { useQuery } from "@tanstack/react-query";
import { useChainId, useReadContract } from "wagmi";

import { canActOnSitting } from "@/lib/actors";
import { accountAbi, vaultAbi } from "@/lib/abi";
import { api } from "@/lib/api";
import { enforcePolicy } from "@/lib/checks";
import { DEMO_WALLET } from "@/lib/config";
import { units6 } from "@/lib/format";
import { kredxoOn } from "@/lib/networks";
import { useProtocolBook } from "@/lib/use-protocol-book";
import { useViewWallet } from "@/lib/use-view-wallet";

export function useCreditState() {
  const { wallet, isConnected } = useViewWallet();
  const chainId = useChainId();
  const kredxo = kredxoOn(chainId);
  const book = useProtocolBook();
  const sitting = canActOnSitting(wallet);
  const creditWallet = sitting ? DEMO_WALLET : wallet;
  const liveAccount = Boolean(kredxo.tradingAccount && sitting);

  const credit = useQuery({
    queryKey: ["credit", creditWallet],
    queryFn: () => api.credit(creditWallet as string),
    enabled: Boolean(creditWallet),
  });
  const risk = useQuery({
    queryKey: ["risk", creditWallet],
    queryFn: () => api.risk(creditWallet as string),
    enabled: Boolean(creditWallet),
  });
  const policyQ = useQuery({
    queryKey: ["policy", creditWallet],
    queryFn: () => api.policy(creditWallet as string),
    enabled: Boolean(creditWallet),
  });

  const limit = useReadContract({
    address: kredxo.tradingAccount || undefined,
    abi: accountAbi,
    functionName: "creditLimit",
    query: { enabled: liveAccount },
  });
  const usedQ = useReadContract({
    address: kredxo.tradingAccount || undefined,
    abi: accountAbi,
    functionName: "usedCredit",
    query: { enabled: liveAccount },
  });
  const idleQ = useReadContract({
    address: kredxo.tradingAccount || undefined,
    abi: accountAbi,
    functionName: "idleUsdc",
    query: { enabled: liveAccount },
  });
  const allocatedOfQ = useReadContract({
    address: kredxo.vault || undefined,
    abi: vaultAbi,
    functionName: "allocatedOf",
    args: [DEMO_WALLET],
    query: { enabled: Boolean(kredxo.vault) },
  });

  const issuedOnchain = liveAccount && limit.data !== undefined ? units6(limit.data) : null;
  const used = liveAccount && usedQ.data !== undefined ? (units6(usedQ.data) ?? 0) : 0;
  const idle = liveAccount && idleQ.data !== undefined ? (units6(idleQ.data) ?? 0) : 0;
  const traderAllocated = units6(allocatedOfQ.data) ?? book.allocated;

  const recommended = Number(credit.data?.base_credit ?? risk.data?.base_credit ?? 0);
  const pythonCurrent = Number(risk.data?.current_credit ?? 0);
  const issued = issuedOnchain ?? (sitting ? pythonCurrent : 0);
  const available = Math.max(issued - used, 0);
  const pythonPolicy = policyQ.data?.policy ?? risk.data?.policy ?? null;
  const policy = enforcePolicy(pythonPolicy, sitting ? issuedOnchain : 0);
  const riskLevel = book.riskLevel !== "—" ? book.riskLevel : (policy?.riskLevel ?? risk.data?.risk_level ?? "—");

  return {
    wallet,
    creditWallet,
    isConnected,
    sitting,
    kredxo,
    credit,
    risk,
    policyQ,
    book,
    recommended,
    issued,
    issuedOnchain,
    used,
    idle,
    available,
    tvl: book.tvl,
    allocated: book.allocated,
    utilized: book.utilized,
    availableLiquidity: book.available,
    traderAllocated,
    policy,
    pythonPolicy,
    riskLevel,
    score: credit.data?.score,
    tier: credit.data?.tier,
    traderMult: risk.data ? Number(risk.data.trader_multiplier) : null,
    marketMult: risk.data ? Number(risk.data.market_multiplier) : null,
    refetchOnchain: async () => {
      await Promise.all([
        limit.refetch(),
        usedQ.refetch(),
        idleQ.refetch(),
        allocatedOfQ.refetch(),
        book.refetch(),
      ]);
    },
  };
}
