export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";
export const DEMO_WALLET =
  process.env.NEXT_PUBLIC_DEMO_WALLET ??
  "0x83000000000000000000000000000000000009A2";

function optionalAddress(value: string | undefined): `0x${string}` | undefined {
  return value && /^0x[0-9a-fA-F]{40}$/.test(value) ? (value as `0x${string}`) : undefined;
}

export const VAULT_ADDRESS = optionalAddress(process.env.NEXT_PUBLIC_VAULT_ADDRESS);
export const USDC_ADDRESS = optionalAddress(process.env.NEXT_PUBLIC_USDC_ADDRESS);
export const TRADING_ACCOUNT_ADDRESS = optionalAddress(
  process.env.NEXT_PUBLIC_TRADING_ACCOUNT_ADDRESS,
);
export const RISK_CONTROLLER_ADDRESS = optionalAddress(
  process.env.NEXT_PUBLIC_RISK_CONTROLLER_ADDRESS,
);

export const MARKET_ADDR = {
  BTC: (process.env.NEXT_PUBLIC_BTC_MARKET ??
    "0x0000000000000000000000000000000000000b7c") as `0x${string}`,
  ETH: (process.env.NEXT_PUBLIC_ETH_MARKET ??
    "0x0000000000000000000000000000000000000e7c") as `0x${string}`,
} as const;
