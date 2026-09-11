import { defineChain } from "viem";

export const MONAD_TESTNET_ID = 10143;
export const MONAD_MAINNET_ID = 143;

const testnetRpc =
  process.env.NEXT_PUBLIC_MONAD_RPC_URL ?? "https://testnet-rpc.monad.xyz";
const testnetWs =
  process.env.NEXT_PUBLIC_MONAD_WS_URL ?? "wss://testnet-rpc.monad.xyz";
const mainnetRpc =
  process.env.NEXT_PUBLIC_MONAD_MAINNET_RPC_URL ?? "https://rpc.monad.xyz";
const mainnetWs =
  process.env.NEXT_PUBLIC_MONAD_MAINNET_WS_URL ?? "wss://rpc.monad.xyz";

export const monadTestnet = defineChain({
  id: MONAD_TESTNET_ID,
  name: "Monad Testnet",
  nativeCurrency: { name: "Monad", symbol: "MON", decimals: 18 },
  rpcUrls: {
    default: {
      http: [testnetRpc],
      webSocket: [testnetWs],
    },
  },
  blockExplorers: {
    default: { name: "MonadVision", url: "https://testnet.monadvision.com" },
  },
  testnet: true,
});

export const monadMainnet = defineChain({
  id: MONAD_MAINNET_ID,
  name: "Monad",
  nativeCurrency: { name: "Monad", symbol: "MON", decimals: 18 },
  rpcUrls: {
    default: {
      http: [mainnetRpc],
      webSocket: [mainnetWs],
    },
  },
  blockExplorers: {
    default: { name: "MonadVision", url: "https://monadvision.com" },
  },
  testnet: false,
});

/** Default app view is testnet. Kredxo contracts are not on mainnet yet. */
export const monadNetwork = {
  chainId: MONAD_TESTNET_ID,
  rpcUrl: testnetRpc,
  wsUrl: testnetWs,
  explorerUrl: "https://testnet.monadvision.com",
  nativeSymbol: "MON",
  blockFrequencyMs: 300,
  finalityMs: 600,
  tps: 10_000,
};
