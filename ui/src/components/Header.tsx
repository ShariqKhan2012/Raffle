"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";

export function Header() {
  return (
    <header className="sticky top-0 z-50 border-b border-white/10 bg-zinc-950/80 backdrop-blur-md">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-violet-600">
            <span className="text-lg">🎲</span>
          </div>
          <div>
            <h1 className="text-sm font-bold tracking-tight text-white">VRF Raffle</h1>
            <p className="text-xs text-zinc-400">Powered by Chainlink</p>
          </div>
        </div>
        <ConnectButton showBalance={false} />
      </div>
    </header>
  );
}
