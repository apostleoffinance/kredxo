import { defineChain } from "viem";

const rpcUrl =
  process.env.NEXT_PUBLIC_MONAD_RPC_URL ?? "https://testnet-rpc.monad.xyz";
const wsUrl =
  process.env.NEXT_PUBLIC_MONAD_WS_URL ?? "wss://testnet-rpc.monad.xyz";
const explorerUrl =
  process.env.NEXT_PUBLIC_MONAD_EXPLORER_URL ??
  "https://testnet.monadvision.com";
const chainId = Number(process.env.NEXT_PUBLIC_MONAD_CHAIN_ID ?? "10143");

export const monadTestnet = defineChain({
  id: chainId,
  name: chainId === 143 ? "Monad" : "Monad Testnet",
  nativeCurrency: { name: "Monad", symbol: "MON", decimals: 18 },
  rpcUrls: {
    default: {
      http: [rpcUrl],
      webSocket: [wsUrl],
    },
  },
  blockExplorers: {
    default: { name: "MonadVision", url: explorerUrl },
  },
  testnet: chainId !== 143,
});

export const monadNetwork = {
  chainId,
  rpcUrl,
  wsUrl,
  explorerUrl,
  nativeSymbol: "MON",
  blockFrequencyMs: 300,
  finalityMs: 600,
  tps: 10_000,
};
