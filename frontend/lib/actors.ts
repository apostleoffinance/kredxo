import { DEMO_WALLET, OPERATOR_ADDRESS } from "./config";
import { sameAddr } from "./format";

export function isSittingTrader(addr?: string | null) {
  return sameAddr(addr, DEMO_WALLET);
}

export function isOperator(addr?: string | null) {
  return sameAddr(addr, OPERATOR_ADDRESS);
}

/** Trader key or operator can draw, trade, and close on the sitting account. */
export function canActOnSitting(addr?: string | null) {
  return isSittingTrader(addr) || isOperator(addr);
}
