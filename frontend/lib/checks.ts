import type { OnchainPolicy, PolicyJson } from "./api";

export type TradeCheck = {
  id: string;
  label: string;
  ok: boolean;
  detail: string;
};

/** Scale an onchain policy payload down to vault-capped issued credit. */
export function capOnchainPolicy(onchain: OnchainPolicy, issuedUsd: number): OnchainPolicy {
  const issuedRaw = Math.max(0, Math.round(issuedUsd * 1e6));
  const current = onchain.creditLimit;
  if (issuedRaw === 0) return { ...onchain, creditLimit: 0 };
  if (!current || issuedRaw >= current) return onchain;
  const scale = issuedRaw / current;
  return {
    ...onchain,
    creditLimit: issuedRaw,
    dailyLossLimit: Math.max(1, Math.floor(onchain.dailyLossLimit * scale)),
    markets: onchain.markets.map((row) => ({
      ...row,
      limit: Math.max(1, Math.floor(row.limit * scale)),
    })),
  };
}

/** Cap Python policy to onchain issued credit so Execute/Account do not show $50k as live. */
export function enforcePolicy(policy: PolicyJson | null, issued: number | null): PolicyJson | null {
  if (!policy) return null;
  if (issued === null) return policy;
  if (issued <= 0) {
    return {
      ...policy,
      creditLimit: 0,
      dailyLossLimit: 0,
      markets: Object.fromEntries(Object.entries(policy.markets).map(([symbol]) => [symbol, 0])),
    };
  }
  const cap = (value: number) => Math.min(value, issued);
  return {
    ...policy,
    creditLimit: cap(policy.creditLimit),
    dailyLossLimit: cap(policy.dailyLossLimit),
    markets: Object.fromEntries(
      Object.entries(policy.markets).map(([symbol, limit]) => [symbol, cap(limit)]),
    ),
  };
}

export function reviewTrade(input: {
  policy: PolicyJson | null;
  market: string;
  size: number;
  leverage: number;
  dailyLoss?: number;
}): TradeCheck[] {
  const { policy, market, size, leverage, dailyLoss = 0 } = input;
  const limit = policy?.markets[market] ?? 0;
  return [
    {
      id: "policy",
      label: "Active policy",
      ok: Boolean(policy && policy.creditLimit > 0),
      detail: policy ? `${policy.riskLevel} · ${policy.creditLimit} limit` : "no policy",
    },
    {
      id: "market",
      label: "Market allowed",
      ok: Boolean(policy && limit > 0),
      detail: limit > 0 ? `${market} cap ${limit}` : `${market} not in policy`,
    },
    {
      id: "leverage",
      label: "Leverage",
      ok: Boolean(policy && leverage > 0 && leverage <= policy.maxLeverage),
      detail: policy ? `max ${policy.maxLeverage}x` : "—",
    },
    {
      id: "exposure",
      label: "Position limit",
      ok: Boolean(policy && size > 0 && size <= limit),
      detail: limit > 0 ? `${size} / ${limit}` : "no cap",
    },
    {
      id: "credit",
      label: "Credit / margin",
      ok: Boolean(policy && size > 0 && leverage > 0 && size / leverage <= policy.creditLimit),
      detail: leverage > 0 ? `margin ${Math.round(size / leverage)}` : "set leverage",
    },
    {
      id: "loss",
      label: "Daily loss",
      ok: Boolean(policy && dailyLoss < policy.dailyLossLimit),
      detail: policy ? `${dailyLoss} / ${policy.dailyLossLimit}` : "—",
    },
  ];
}
