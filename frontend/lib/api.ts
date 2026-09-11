import { API_URL } from "./config";

export type CreditResponse = {
  wallet: string;
  score: number;
  tier: string;
  base_credit: string;
  metrics: Record<string, string | number>;
  components: Record<string, string>;
};

export type RiskResponse = {
  wallet: string;
  base_credit: string;
  current_credit: string;
  trader_multiplier: string;
  market_multiplier: string;
  risk_level: string;
  trader_risk: Record<string, string | number>;
  market_risk: Record<string, string>;
  account_risk: Record<string, string>;
  policy: PolicyJson;
};

export type PolicyJson = {
  creditLimit: number;
  maxLeverage: number;
  dailyLossLimit: number;
  markets: Record<string, number>;
  riskLevel: string;
};

export type OnchainPolicy = {
  creditLimit: number;
  maxLeverage: number;
  dailyLossLimit: number;
  riskLevel: number;
  markets: { symbol: string; limit: number }[];
};

export type PolicyResponse = {
  wallet: string;
  risk_level: string;
  policy: PolicyJson;
  onchain: OnchainPolicy;
};

export type CreditRequestResponse = {
  wallet: string;
  score: number;
  tier: string;
  base_credit: string;
  current_credit: string;
  policy: PolicyJson;
  onchain: OnchainPolicy;
};

export type TradesResponse = {
  wallet: string;
  count: number;
  volume: string;
  realized_pnl: string;
  trades: {
    id: number;
    market: string;
    side: string;
    size: string;
    pnl: string | null;
    leverage: string;
    timestamp: string;
    tx_hash: string;
  }[];
};

export type MarketsResponse = {
  base_apr: string;
  utilization_premium_max: string;
  current_apr: string;
  apr: { low: string; normal: string; high: string };
  tvl: string;
  allocated: string;
  utilized: string;
  utilization: string;
  vault: string | null;
  usdc: string | null;
};

export type MarketShock = {
  volatility: number;
  liquidity: number;
  price_move: number;
  correlation: number;
  funding: number;
};

export const NORMAL_MARKET: MarketShock = {
  volatility: 0.2,
  liquidity: 1,
  price_move: 0,
  correlation: 0.5,
  funding: 0,
};

export const HIGH_SHOCK: MarketShock = {
  volatility: 0.37,
  liquidity: 0.72,
  price_move: 0.12,
  correlation: 0.7,
  funding: 0,
};

export type StressStage = {
  name: string;
  risk_level: string;
  current_credit: string;
  trader_multiplier: string;
  market_multiplier: string;
  policy: PolicyJson;
  onchain: PolicyResponse["onchain"];
};

export type StressResponse = {
  wallet: string;
  score: number;
  tier: string;
  base_credit: string;
  injection: Record<string, string>;
  stages: {
    normal: StressStage;
    shock: StressStage;
    elevated: StressStage;
    recovered: StressStage;
  };
  trade: {
    market: string;
    size: number;
    leverage: number;
    allowed_before: boolean;
    allowed_after_shock: boolean;
    allowed_after_elevated: boolean;
    allowed_after_recovery: boolean;
  };
};

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, { cache: "no-store" });
  if (!res.ok) throw new Error(`${path} ${res.status}`);
  return res.json() as Promise<T>;
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`${path} ${res.status}`);
  return res.json() as Promise<T>;
}

export type DemoResponse = {
  phase: number;
  product: { tagline: string; one_liner: string; principle: string };
  network: {
    name: string;
    chain_id: number;
    explorer: string;
    tps: number;
    block_frequency_ms: number;
    finality_ms: number;
  };
  demo_wallet: string;
  lp: string | null;
  contracts: Record<string, string | null>;
  seed: {
    deposited: string;
    credit: string;
    btcLimit: string;
    note: string;
    txs: Record<string, string>;
  } | null;
  sitting: {
    canonical: Record<string, number | string>;
    live: Record<string, number | string>;
  };
  venues: {
    adapter0: string;
    first: string;
    second: string;
    later: string;
    not_this_phase: string[];
    testnet: {
      chain_id: number;
      kuru_router: string;
      kuru_usdc: string;
      perpl_exchange: string;
      perpl_collateral: string;
      vault_usdc: string;
      kuru_usdc_match: boolean;
      perpl_collateral_match: boolean;
    };
    pay_venue: string;
  };
};

export const api = {
  health: () => get<{ phase: number; status: string; monad: { rpc_ok: boolean } }>("/health"),
  demo: () => get<DemoResponse>("/api/demo"),
  credit: (wallet: string) => get<CreditResponse>(`/api/credit/${wallet}`),
  risk: (wallet: string) => get<RiskResponse>(`/api/risk/${wallet}`),
  policy: (wallet: string) => get<PolicyResponse>(`/api/policy/${wallet}`),
  trades: (wallet: string) => get<TradesResponse>(`/api/trades/${wallet}`),
  markets: () => get<MarketsResponse>("/api/markets"),
  positions: (wallet: string) =>
    get<{ wallet: string; positions: unknown[] }>(`/api/positions/${wallet}`),
  requestCredit: (wallet: string, market?: MarketShock) =>
    post<CreditRequestResponse>("/credit/request", { wallet, market }),
  evaluateRisk: (wallet: string, market: MarketShock) =>
    post<RiskResponse>("/risk/evaluate", { wallet, market }),
  proposePolicy: (wallet: string, market: MarketShock) =>
    post<PolicyResponse>("/policy/propose", { wallet, market }),
  simulateStress: (wallet: string) =>
    post<StressResponse>("/stress/simulate", { wallet }),
};
