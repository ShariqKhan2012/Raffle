import type { Abi } from "viem";
import RaffleArtifact from "../lib/abi/Raffle.json";

export const RAFFLE_ABI = RaffleArtifact.abi as Abi;

const ANVIL_ID = 31337;
const SEPOLIA_ID = 11155111;

const ADDRESS_MAP: Partial<Record<number, `0x${string}`>> = {
  [ANVIL_ID]: (process.env.NEXT_PUBLIC_ANVIL_RAFFLE_ADDRESS || "") as `0x${string}`,
  [SEPOLIA_ID]: (process.env.NEXT_PUBLIC_SEPOLIA_RAFFLE_ADDRESS || "") as `0x${string}`,
};

export function getRaffleAddress(chainId: number): `0x${string}` | undefined {
  const addr = ADDRESS_MAP[chainId];
  return addr && addr.length > 2 ? addr : undefined;
}

export function getChainName(chainId: number): string {
  if (chainId === ANVIL_ID) return "Anvil (Local)";
  if (chainId === SEPOLIA_ID) return "Sepolia";
  return "Unknown Network";
}

export function explorerTx(hash: string, chainId: number): string | null {
  return chainId === SEPOLIA_ID ? `https://sepolia.etherscan.io/tx/${hash}` : null;
}

export function explorerAddress(addr: string, chainId: number): string | null {
  return chainId === SEPOLIA_ID ? `https://sepolia.etherscan.io/address/${addr}` : null;
}
