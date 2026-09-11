import {
  EXECUTION_ROUTER_ADDRESS,
  REGISTRY_ADDRESS,
  RISK_CONTROLLER_ADDRESS,
  RISK_POLICY_ADDRESS,
  SETTLEMENT_ADDRESS,
  TRADING_ACCOUNT_ADDRESS,
  USDC_ADDRESS,
  VAULT_ADDRESS,
} from "./config";
import { MONAD_MAINNET_ID, MONAD_TESTNET_ID } from "./monad";

/** Official Kuru + Perpl addresses. Confirmed 2026-09-11 from docs.kuru.io and Perpl api-docs. */
export const VENUES = {
  [MONAD_TESTNET_ID]: {
    kuruRouter: "0x7EFbE105Ca7415dE98F96622173458ac1c054630",
    kuruUsdc: "0x3bA3d39AFcf8bb994f7964B3e0171Ea2Ba361570",
    kuruMonUsdc: "0xa241896A7Dbe8a550D2E5fF7A914bB1989ceD2D9",
    perplExchange: "0x1964C32f0bE608E7D29302AFF5E61268E72080cc",
    perplCollateral: "0xdF5B718d8FcC173335185a2a1513eE8151e3c027",
    circleUsdc: "0x534b2f3A21130d7a60830c2Df862319e593943A3",
  },
  [MONAD_MAINNET_ID]: {
    kuruRouter: "0xd651346d7c789536ebf06dc72aE3C8502cd695CC",
    kuruUsdc: "0x754704Bc059F8C67012fEd69BC8A327a5aafb603",
    kuruMonUsdc: undefined as string | undefined,
    perplExchange: "0x34B6552d57a35a1D042CcAe1951BD1C370112a6F",
    perplCollateral: "0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a",
    circleUsdc: undefined as string | undefined,
  },
} as const;

const TESTNET_KREDXO = {
  vault: VAULT_ADDRESS,
  usdc: USDC_ADDRESS,
  tradingAccount: TRADING_ACCOUNT_ADDRESS,
  riskController: RISK_CONTROLLER_ADDRESS,
  riskPolicy: RISK_POLICY_ADDRESS,
  settlement: SETTLEMENT_ADDRESS,
  registry: REGISTRY_ADDRESS,
  executionRouter: EXECUTION_ROUTER_ADDRESS,
};

export function kredxoOn(chainId: number) {
  if (chainId === MONAD_TESTNET_ID) return TESTNET_KREDXO;
  return {
    vault: undefined,
    usdc: undefined,
    tradingAccount: undefined,
    riskController: undefined,
    riskPolicy: undefined,
    settlement: undefined,
    registry: undefined,
    executionRouter: undefined,
  };
}

export function explorerFor(chainId: number) {
  return chainId === MONAD_MAINNET_ID
    ? "https://monadvision.com"
    : "https://testnet.monadvision.com";
}

function sameAddr(a?: string, b?: string) {
  return Boolean(a && b && a.toLowerCase() === b.toLowerCase());
}

export function venueSettlement(chainId: number, venue: "kuru" | "perpl") {
  const book = VENUES[chainId as keyof typeof VENUES];
  if (!book) return { token: undefined, matchesVault: false };
  const vaultUsdc = kredxoOn(chainId).usdc ?? (chainId === MONAD_TESTNET_ID ? book.circleUsdc : undefined);
  const token = venue === "kuru" ? book.kuruUsdc : book.perplCollateral;
  return { token, matchesVault: sameAddr(vaultUsdc, token) };
}
