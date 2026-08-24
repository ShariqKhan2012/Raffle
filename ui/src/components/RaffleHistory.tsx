"use client";

import { RAFFLE_ABI, getRaffleAddress } from "@/lib/constants";
import { formatEther } from "viem";
import { useReadContracts } from "wagmi";

type RaffleInfo = {
  prizeMoney: bigint;
  numParticipants: bigint;
  winner: `0x${string}`;
};

function short(addr: `0x${string}`) {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

function SkeletonRow() {
  return (
    <div className="flex items-center gap-3 px-4 py-3 border-b border-white/5 last:border-0 animate-pulse">
      <div className="h-5 w-7 rounded bg-white/10 shrink-0" />
      <div className="flex-1 space-y-1.5">
        <div className="h-3.5 w-20 rounded bg-white/10" />
        <div className="h-3 w-32 rounded bg-white/10" />
      </div>
      <div className="h-3 w-14 rounded bg-white/10" />
    </div>
  );
}

export function RaffleHistory() {
  const raffleAddress = getRaffleAddress();

  const { data, isLoading } = useReadContracts({
    contracts: raffleAddress
      ? [
          {
            address: raffleAddress,
            abi: RAFFLE_ABI,
            functionName: "getRaffleHistory",
          },
          {
            address: raffleAddress,
            abi: RAFFLE_ABI,
            functionName: "getRaffleCounter",
          },
        ]
      : [],
    query: { enabled: !!raffleAddress, refetchInterval: 3000 },
  });

  if (!raffleAddress) return null;

  const history = (data?.[0]?.result as readonly RaffleInfo[] | undefined) ?? [];
  // history[i] = round i+1; show newest first
  const rounds = [...history].map((r, i) => ({ ...r, round: i + 1 })).reverse();

  return (
    <aside
      className="w-full rounded-2xl border border-white/10 bg-white/[0.03] flex flex-col overflow-hidden"
      style={{ maxHeight: 560 }}
    >
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3.5 border-b border-white/10 shrink-0">
        <span className="text-xs font-semibold uppercase tracking-widest text-zinc-400">
          Raffle History
        </span>
        <span className="inline-flex items-center rounded-full bg-violet-500/15 px-2.5 py-0.5 text-xs font-medium text-violet-300 tabular-nums">
          {isLoading ? "—" : `${history.length} round${history.length !== 1 ? "s" : ""}`}
        </span>
      </div>

      {/* Body */}
      {isLoading ? (
        <div>
          {[0, 1, 2].map((i) => (
            <SkeletonRow key={i} />
          ))}
        </div>
      ) : rounds.length === 0 ? (
        <div className="flex flex-1 flex-col items-center justify-center py-14 px-6 text-center">
          <div
            className="mb-3 flex h-10 w-10 items-center justify-center rounded-xl bg-white/5"
            aria-hidden
          >
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
              <circle cx="10" cy="10" r="7.5" stroke="#52525b" strokeWidth="1.25" />
              <path d="M10 6.5v3.75M10 12.5h.01" stroke="#52525b" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
          </div>
          <p className="text-sm font-medium text-zinc-400">No rounds yet</p>
          <p className="mt-1 text-xs text-zinc-600">
            Completed draws will appear here.
          </p>
        </div>
      ) : (
        <div className="overflow-y-auto flex-1" style={{ scrollbarWidth: "thin" }}>
          {rounds.map(({ round, prizeMoney, numParticipants, winner }) => (
            <div
              key={round}
              className="group px-4 py-3.5 border-b border-white/5 last:border-0 transition-colors hover:bg-white/[0.04] space-y-2.5"
            >
              {/* Top row: round badge + prize pool */}
              <div className="flex items-center justify-between gap-2">
                <span className="inline-flex h-5 items-center justify-center rounded bg-violet-500/20 px-2 text-[10px] font-bold tabular-nums text-violet-300">
                  Round #{round}
                </span>
                <div className="flex items-baseline gap-1">
                  <span className="text-[10px] uppercase tracking-wide text-zinc-500">Prize Pool</span>
                  <span
                    className="text-xs font-semibold tabular-nums"
                    style={{ color: "#f59e0b" }}
                  >
                    {parseFloat(formatEther(prizeMoney)).toFixed(4)} ETH
                  </span>
                </div>
              </div>

              {/* Winner */}
              <div>
                <p className="text-[10px] uppercase tracking-wide text-zinc-500 mb-0.5">Winner</p>
                <p className="font-mono text-[11px] leading-tight text-zinc-300 truncate">
                  {winner}
                </p>
              </div>

              {/* Participants */}
              <div>
                <p className="text-[10px] uppercase tracking-wide text-zinc-500 mb-0.5">Participants</p>
                <p className="text-[11px] text-zinc-300">
                  {numParticipants.toString()}{" "}
                  {Number(numParticipants) === 1 ? "player" : "players"}
                </p>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Footer hint when scrollable */}
      {rounds.length > 5 && (
        <div className="shrink-0 border-t border-white/5 px-4 py-2 text-center text-[10px] text-zinc-700">
          scroll for older rounds
        </div>
      )}
    </aside>
  );
}
