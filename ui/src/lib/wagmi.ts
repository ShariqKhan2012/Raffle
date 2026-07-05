import { connectorsForWallets } from "@rainbow-me/rainbowkit";
import {
  injectedWallet,
  coinbaseWallet,
  walletConnectWallet,
} from "@rainbow-me/rainbowkit/wallets";
import { createConfig, http } from "wagmi";
import { anvil, mainnet, sepolia } from "wagmi/chains";

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

export const config = createConfig({
  chains: [anvil, sepolia, mainnet],
  connectors,
  transports: {
    [anvil.id]: http("http://127.0.0.1:8545"),
    [sepolia.id]: http(),
    [mainnet.id]: http("https://cloudflare-eth.com"),
  },
  ssr: true,
});
