import { injected } from "@wagmi/core";
import { http } from "wagmi";
import { createConfig } from "wagmi";

import { monadTestnet } from "./monad";

export const wagmiConfig = createConfig({
  chains: [monadTestnet],
  connectors: [injected()],
  transports: {
    [monadTestnet.id]: http(monadTestnet.rpcUrls.default.http[0]),
  },
  ssr: true,
});
