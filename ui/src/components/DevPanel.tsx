"use client";

import { useState } from "react";
import { parseAbi } from "viem";
import { usePublicClient, useWriteContract } from "wagmi";
import { RAFFLE_ABI } from "@/lib/constants";

const VRF_MOCK_ABI = parseAbi([
  "function fulfillRandomWords(uint256 _requestId, address _consumer) nonpayable",
]);

type Status =
  | "idle"
  | "upkeep-pending"
  | "upkeep-confirming"
  | "fulfill-pending"
  | "fulfill-confirming";

interface Props {
  raffleAddress: `0x${string}`;
  vrfCoordinator: `0x${string}`;
  isProcessing: boolean;
  upkeepNeeded: boolean;
  lastRequestId: bigint;
  isAnvil: boolean;
  refetch: () => void;
}

export function DevPanel({
  raffleAddress,
  vrfCoordinator,
  isProcessing,
  upkeepNeeded,
  lastRequestId,
  isAnvil,
  refetch,
}: Props) {
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | undefined>();

  const publicClient = usePublicClient();
  const { writeContractAsync: writeUpkeep } = useWriteContract();
  const { writeContractAsync: writeFulfill } = useWriteContract();

  const isBusy = status !== "idle";

  // Anvil: button active when upkeep conditions are met OR raffle is already processing (skip to fulfill).
  // Sepolia: button active only when upkeep conditions are met AND raffle is NOT yet processing
  //          (once processing, the real VRF node takes over — we cannot call fulfillRandomWords).
  const canRun = isAnvil
    ? (upkeepNeeded || isProcessing) && !isBusy
    : upkeepNeeded && !isProcessing && !isBusy;

  function buttonLabel(): string {
    if (isBusy) {
      if (status === "upkeep-pending") return "Confirm in wallet…";
      if (status === "upkeep-confirming") return "Triggering draw…";
      if (status === "fulfill-pending") return "Confirm in wallet…";
      if (status === "fulfill-confirming") return "Picking winner…";
    }
    if (!isAnvil && isProcessing) return "Waiting for Chainlink VRF…";
    if (isProcessing) return "Complete Draw (deliver randomness)";
    return "Manually Pick Winner";
  }

  async function handlePickWinner() {
    if (!publicClient) return;
    setError(undefined);

    try {
      let requestId: bigint;

      if (isProcessing && isAnvil) {
        // Anvil only: performUpkeep was already called, skip straight to fulfill.
        requestId = lastRequestId;
      } else {
        // Step 1: performUpkeep — works on both Anvil and Sepolia.
        setStatus("upkeep-pending");
        const upkeepHash = await writeUpkeep({
          address: raffleAddress,
          abi: RAFFLE_ABI,
          functionName: "performUpkeep",
          args: ["0x"],
        });

        setStatus("upkeep-confirming");
        await publicClient.waitForTransactionReceipt({ hash: upkeepHash });

        if (!isAnvil) {
          // Sepolia: our job ends here. The real Chainlink VRF node will call
          // fulfillRandomWords automatically (usually within 1–3 minutes).
          setStatus("idle");
          refetch();
          return;
        }

        // Anvil: read the requestId that performUpkeep stored on-chain.
        requestId = (await publicClient.readContract({
          address: raffleAddress,
          abi: RAFFLE_ABI,
          functionName: "getLastRequestId",
        })) as bigint;
      }

      // Step 2 (Anvil only): deliver randomness via the mock VRF coordinator.
      setStatus("fulfill-pending");
      const fulfillHash = await writeFulfill({
        address: vrfCoordinator,
        abi: VRF_MOCK_ABI,
        functionName: "fulfillRandomWords",
        args: [requestId, raffleAddress],
      });

      setStatus("fulfill-confirming");
      await publicClient.waitForTransactionReceipt({ hash: fulfillHash });

      setStatus("idle");
      refetch();
    } catch (err: unknown) {
      setStatus("idle");
      const raw = err instanceof Error ? err.message : String(err);
      setError(raw.split("\n").find((l) => l.trim().length > 0) ?? raw);
    }
  }

  const waitingForVrf = !isAnvil && isProcessing;

  return (
    <div className="rounded-2xl border border-amber-500/20 bg-amber-500/5 p-6 space-y-4">
      <div>
        <p className="text-xs font-medium uppercase tracking-widest text-amber-400">
          Owner Controls
        </p>
        <p className="mt-0.5 text-xs text-zinc-500">
          {isAnvil
            ? "Anvil: triggers performUpkeep then fulfillRandomWords on the mock coordinator."
            : "Sepolia: triggers performUpkeep. Chainlink VRF node delivers the randomness automatically."}
        </p>
      </div>

      <button
        onClick={handlePickWinner}
        disabled={!canRun}
        className="w-full rounded-xl border border-amber-500/30 bg-amber-500/10 px-4 py-3 text-sm font-semibold text-amber-300 transition-all hover:bg-amber-500/20 disabled:cursor-not-allowed disabled:opacity-40"
      >
        {isBusy ? (
          <span className="flex items-center justify-center gap-2">
            <span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-amber-300 border-t-transparent" />
            {buttonLabel()}
          </span>
        ) : (
          buttonLabel()
        )}
      </button>

      {/* Contextual status message below the button */}
      {waitingForVrf && !isBusy && (
        <div className="rounded-xl border border-blue-500/20 bg-blue-500/5 px-4 py-3 text-xs text-blue-300 space-y-1">
          <p className="font-semibold">VRF request pending</p>
          <p className="text-blue-400/70">
            Chainlink VRF node is processing the request. The winner will be picked automatically — usually within 1–3 minutes on Sepolia. The winner banner will appear when the event fires.
          </p>
        </div>
      )}

      {!canRun && !isBusy && !waitingForVrf && (
        <p className="text-center text-xs text-zinc-600">
          Need at least one player and the draw interval to have elapsed.
        </p>
      )}

      {error && (
        <p className="rounded-xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-xs text-red-400 break-all">
          {error}
        </p>
      )}

      <p className="text-xs text-zinc-600 border-t border-white/5 pt-3">
        {isAnvil ? (
          <>
            On mainnet/Sepolia, <span className="font-mono text-zinc-500">performUpkeep</span> is called
            by Chainlink Automation and <span className="font-mono text-zinc-500">fulfillRandomWords</span> by
            the VRF node. Here you do both manually.
          </>
        ) : (
          <>
            On Sepolia, only <span className="font-mono text-zinc-500">performUpkeep</span> needs
            a manual trigger. The VRF subscription you funded handles the rest.
          </>
        )}
      </p>
    </div>
  );
}
