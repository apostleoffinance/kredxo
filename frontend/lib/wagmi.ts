import { injected } from "@wagmi/core";
import { http } from "wagmi";
import { createConfig } from "wagmi";

import { monadMainnet, monadTestnet } from "./monad";

export const wagmiConfig = createConfig({
  chains: [monadTestnet, monadMainnet],
  connectors: [injected()],
  transports: {
    [monadTestnet.id]: http(monadTestnet.rpcUrls.default.http[0]),
    [monadMainnet.id]: http(monadMainnet.rpcUrls.default.http[0]),
  },
  ssr: true,
});
