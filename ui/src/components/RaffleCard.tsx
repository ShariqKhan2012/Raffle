"use client";

import {
  useAccount,
  useChainId,
  useReadContracts,
  useSwitchChain,
  useWaitForTransactionReceipt,
  useWatchContractEvent,
  useWriteContract,
} from "wagmi";
import { anvil, sepolia } from "wagmi/chains";
import { formatEther } from "viem";
import {
  RAFFLE_ABI,
  getRaffleAddress,
  getChainName,
  explorerTx,
  explorerAddress,
} from "@/lib/constants";
import { CountdownTimer } from "./CountdownTimer";
import { DevPanel } from "./DevPanel";
import { useState } from "react";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000" as const;
const ANVIL_CHAIN_ID = 31337;
const SUPPORTED = [anvil, sepolia];

export function RaffleCard() {
  const { isConnected, address: account } = useAccount();
  const chainId = useChainId();
  const { switchChain, isPending: isSwitching } = useSwitchChain();
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>();
  const [winnerFlash, setWinnerFlash] = useState<`0x${string}` | null>(null);

  const raffleAddress = getRaffleAddress(chainId);
  const isSupported = !!raffleAddress;
  const isAnvil = chainId === ANVIL_CHAIN_ID;
  const chainName = getChainName(chainId);

  // ── Contract reads ──────────────────────────────────────────────────────────
  const { data, refetch, isLoading } = useReadContracts({
    contracts: raffleAddress
      ? [
          { address: raffleAddress, abi: RAFFLE_ABI, functionName: "getRaffleState" },    // 0
          { address: raffleAddress, abi: RAFFLE_ABI, functionName: "getEntryFee" },        // 1
          { address: raffleAddress, abi: RAFFLE_ABI, functionName: "getBalance" },         // 2
          { address: raffleAddress, abi: RAFFLE_ABI, functionName: "getLastWinner" },      // 3
          { address: raffleAddress, abi: RAFFLE_ABI, functionName: "getLastTimestamp" },   // 4
          { address: raffleAddress, abi: RAFFLE_ABI, functionName: "getInterval" },        // 5
          { address: raffleAddress, abi: RAFFLE_ABI, functionName: "getPlayersCount" },    // 6
          { address: raffleAddress, abi: RAFFLE_ABI, functionName: "getLastRequestId" },   // 7
          { address: raffleAddress, abi: RAFFLE_ABI, functionName: "owner" },              // 8
          { address: raffleAddress, abi: RAFFLE_ABI, functionName: "s_vrfCoordinator" },   // 9
          { address: raffleAddress, abi: RAFFLE_ABI, functionName: "checkUpkeep", args: ["0x"] }, // 10
        ]
      : [],
    query: { enabled: isSupported, refetchInterval: 2000 },
  });

  // ── Live winner event (drives the flash banner) ─────────────────────────────
  useWatchContractEvent({
    address: raffleAddress ?? ZERO_ADDRESS,
    abi: RAFFLE_ABI,
    eventName: "Raffle__WinnerPicked",
    onLogs(logs) {
      if (!raffleAddress) return;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const winner = (logs[0] as any)?.args?.player as `0x${string}` | undefined;
      if (winner) {
        setWinnerFlash(winner);
        refetch();
      }
    },
  });

  // ── Write + tx confirmation ──────────────────────────────────────────────────
  const { writeContractAsync, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isConfirmed } =
    useWaitForTransactionReceipt({ hash: txHash });

  // ── Derived state ────────────────────────────────────────────────────────────
  const raffleState = data?.[0]?.result as number | undefined;
  const entryFee = data?.[1]?.result as bigint | undefined;
  const balance = data?.[2]?.result as bigint | undefined;
  const lastWinner = data?.[3]?.result as `0x${string}` | undefined;
  const lastTimestamp = data?.[4]?.result as bigint | undefined;
  const interval = data?.[5]?.result as bigint | undefined;
  const playersCount = data?.[6]?.result as bigint | undefined;
  const lastRequestId = data?.[7]?.result as bigint | undefined;
  const raffleOwner = data?.[8]?.result as `0x${string}` | undefined;
  const vrfCoordinator = data?.[9]?.result as `0x${string}` | undefined;
  const checkUpkeepResult = data?.[10]?.result as readonly [boolean, `0x${string}`] | undefined;
  const upkeepNeeded = checkUpkeepResult?.[0] ?? false;

  const isOpen = raffleState === 0;
  const isProcessing = raffleState === 1;
  const hasWinner = lastWinner && lastWinner !== ZERO_ADDRESS;
  const isOwner =
    !!account && !!raffleOwner && account.toLowerCase() === raffleOwner.toLowerCase();
  // Owner can manually trigger draws on any supported chain.
  // On Anvil: two-step (performUpkeep + fulfillRandomWords on mock).
  // On Sepolia: one-step (performUpkeep only; VRF node fulfills automatically).
  const showDevPanel = isOwner && isSupported && !!vrfCoordinator;

  // ── Handlers ─────────────────────────────────────────────────────────────────
  async function handleEnter() {
    if (!entryFee || !raffleAddress) return;
    try {
      const hash = await writeContractAsync({
        address: raffleAddress,
        abi: RAFFLE_ABI,
        functionName: "enterRaffle",
        value: entryFee,
      });
      setTxHash(hash);
      refetch();
    } catch (err) {
      console.error(err);
    }
  }

  // ── Render ───────────────────────────────────────────────────────────────────
  if (isLoading && isSupported) {
    return (
      <div className="flex items-center justify-center py-24">
        <div className="h-10 w-10 animate-spin rounded-full border-4 border-violet-600 border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-3xl space-y-6">

      {/* Winner flash banner */}
      {winnerFlash && (
        <div className="relative rounded-2xl border border-emerald-500/30 bg-emerald-500/10 px-6 py-5 text-center space-y-2">
          <p className="text-xs font-medium uppercase tracking-widest text-emerald-400">
            Winner Picked!
          </p>
          <p className="break-all font-mono text-sm text-white">{winnerFlash}</p>
          <button
            onClick={() => setWinnerFlash(null)}
            className="mt-1 text-xs text-zinc-500 underline underline-offset-2"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* State badge */}
      <div className="flex items-center gap-3">
        <span
          className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold ${
            isProcessing
              ? "bg-amber-500/20 text-amber-400"
              : "bg-emerald-500/20 text-emerald-400"
          }`}
        >
          <span
            className={`h-2 w-2 rounded-full ${
              isProcessing ? "animate-pulse bg-amber-400" : "bg-emerald-400"
            }`}
          />
          {isProcessing ? "Drawing Winner…" : "Open — Enter Now"}
        </span>
        <span className="text-xs text-zinc-500">{chainName}</span>
      </div>

      {/* Stats grid */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <StatCard
          label="Prize Pool"
          value={balance !== undefined ? `${parseFloat(formatEther(balance)).toFixed(4)} ETH` : "—"}
          accent="violet"
        />
        <StatCard
          label="Entry Fee"
          value={entryFee !== undefined ? `${parseFloat(formatEther(entryFee)).toFixed(4)} ETH` : "—"}
          accent="blue"
        />
        <StatCard
          label="Players"
          value={playersCount !== undefined ? playersCount.toString() : "—"}
          accent="cyan"
        />
        <StatCard
          label="Draw Interval"
          value={interval !== undefined ? `${Number(interval)}s` : "—"}
          accent="purple"
        />
      </div>

      {/* Countdown */}
      {lastTimestamp !== undefined && interval !== undefined && (
        <div className="rounded-2xl border border-white/10 bg-white/5 px-6 py-5">
          <p className="mb-1 text-xs font-medium uppercase tracking-widest text-zinc-500">
            Next Draw In
          </p>
          <CountdownTimer lastTimestamp={lastTimestamp} interval={interval} />
        </div>
      )}

      {/* Last winner (persistent) */}
      {hasWinner && !winnerFlash && (
        <div className="rounded-2xl border border-violet-500/20 bg-violet-500/5 px-6 py-4">
          <p className="mb-1 text-xs font-medium uppercase tracking-widest text-violet-400">
            Last Winner
          </p>
          <p className="break-all font-mono text-sm text-white">{lastWinner}</p>
        </div>
      )}

      {/* CTA */}
      <div className="rounded-2xl border border-white/10 bg-white/5 p-6">
        {!isConnected ? (
          <p className="text-center text-sm text-zinc-400">
            Connect your wallet to enter the raffle.
          </p>
        ) : !isSupported ? (
          // Unsupported chain — show switch options for every supported chain
          <div className="text-center space-y-3">
            <p className="text-sm text-zinc-400">
              No raffle on <span className="text-white font-medium">{chainName}</span>. Switch to:
            </p>
            <div className="flex gap-2 justify-center">
              {SUPPORTED.map((chain) => (
                <button
                  key={chain.id}
                  onClick={() => switchChain({ chainId: chain.id })}
                  disabled={isSwitching}
                  className="rounded-xl bg-violet-600 px-5 py-2.5 text-sm font-semibold text-white transition-all hover:bg-violet-500 disabled:opacity-50"
                >
                  {isSwitching ? "Switching…" : chain.name}
                </button>
              ))}
            </div>
          </div>
        ) : isConfirmed ? (
          <div className="text-center">
            <p className="text-emerald-400 font-semibold">You&apos;re in! Good luck</p>
            <button
              onClick={() => { setTxHash(undefined); refetch(); }}
              className="mt-3 text-xs text-zinc-400 underline underline-offset-2"
            >
              Enter again
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            <div>
              <p className="text-sm font-semibold text-white">Enter Raffle</p>
              <p className="mt-0.5 text-xs text-zinc-400">
                Cost: {entryFee ? `${formatEther(entryFee)} ETH` : "—"} — winner takes the entire prize pool
              </p>
            </div>
            <button
              onClick={handleEnter}
              disabled={!isOpen || isPending || isConfirming}
              className="w-full rounded-xl bg-violet-600 px-6 py-3 text-sm font-semibold text-white transition-all hover:bg-violet-500 disabled:cursor-not-allowed disabled:opacity-50"
            >
              {isPending
                ? "Confirm in wallet…"
                : isConfirming
                ? "Confirming…"
                : isProcessing
                ? "Draw in progress"
                : "Enter Raffle"}
            </button>
            {txHash && (() => {
              const url = explorerTx(txHash, chainId);
              return (
                <p className="text-center text-xs text-zinc-500">
                  Tx:{" "}
                  {url ? (
                    <a href={url} target="_blank" rel="noopener noreferrer"
                      className="text-violet-400 underline underline-offset-2">
                      {txHash.slice(0, 10)}…{txHash.slice(-8)}
                    </a>
                  ) : (
                    <span className="font-mono text-violet-400">
                      {txHash.slice(0, 10)}…{txHash.slice(-8)}
                    </span>
                  )}
                </p>
              );
            })()}
          </div>
        )}
      </div>

      {/* Dev panel — Anvil owner only */}
      {showDevPanel && (
        <DevPanel
          raffleAddress={raffleAddress!}
          vrfCoordinator={vrfCoordinator!}
          isProcessing={isProcessing}
          upkeepNeeded={upkeepNeeded}
          lastRequestId={lastRequestId ?? BigInt(0)}
          isAnvil={isAnvil}
          refetch={refetch}
        />
      )}

      {/* Contract link */}
      {raffleAddress && (
        <p className="text-center text-xs text-zinc-600">
          Contract:{" "}
          {(() => {
            const url = explorerAddress(raffleAddress, chainId);
            return url ? (
              <a href={url} target="_blank" rel="noopener noreferrer"
                className="text-violet-500 underline underline-offset-2">
                {raffleAddress.slice(0, 8)}…{raffleAddress.slice(-6)}
              </a>
            ) : (
              <span className="font-mono text-violet-500">
                {raffleAddress.slice(0, 8)}…{raffleAddress.slice(-6)}
              </span>
            );
          })()}
        </p>
      )}
    </div>
  );
}

function StatCard({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent: "violet" | "blue" | "cyan" | "purple";
}) {
  const colors = {
    violet: "border-violet-500/20 bg-violet-500/5 text-violet-300",
    blue: "border-blue-500/20 bg-blue-500/5 text-blue-300",
    cyan: "border-cyan-500/20 bg-cyan-500/5 text-cyan-300",
    purple: "border-purple-500/20 bg-purple-500/5 text-purple-300",
  };
  return (
    <div className={`rounded-2xl border px-4 py-4 ${colors[accent]}`}>
      <p className="text-xs font-medium uppercase tracking-widest opacity-60">{label}</p>
      <p className="mt-1.5 text-xl font-bold">{value}</p>
    </div>
  );
}
