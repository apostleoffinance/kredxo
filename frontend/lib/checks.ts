import type { PolicyJson } from "./api";

export type TradeCheck = {
  id: string;
  label: string;
  ok: boolean;
  detail: string;
};

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
