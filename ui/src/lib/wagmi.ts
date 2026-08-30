import { connectorsForWallets } from "@rainbow-me/rainbowkit";
import {
  coinbaseWallet,
  injectedWallet,
  walletConnectWallet,
} from "@rainbow-me/rainbowkit/wallets";
import { createConfig, http } from "wagmi";
import { anvil, sepolia } from "wagmi/chains";

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID!;

const connectors = connectorsForWallets(
  [
    {
      groupName: "Popular",
      wallets: [injectedWallet, coinbaseWallet, walletConnectWallet],
    },
  ],
  { appName: "VRF Raffle", projectId }
);

const chains = process.env.NODE_ENV === "production" ? ([sepolia] as const) : ([anvil, sepolia] as const);
export const config = createConfig({
  chains,
  connectors,
  transports: {
    [anvil.id]: http("http://127.0.0.1:8545"),
    [sepolia.id]: http(),
  },
  ssr: true,
});
