"use client";

import { useEffect, useState } from "react";

interface CountdownTimerProps {
  lastTimestamp: bigint;
  interval: bigint;
}

export function CountdownTimer({ lastTimestamp, interval }: CountdownTimerProps) {
  const [secondsLeft, setSecondsLeft] = useState(0);

  useEffect(() => {
    function calc() {
      const nextDraw = Number(lastTimestamp) + Number(interval);
      const now = Math.floor(Date.now() / 1000);
      return Math.max(0, nextDraw - now);
    }

    setSecondsLeft(calc());
    const id = setInterval(() => setSecondsLeft(calc()), 1000);
    return () => clearInterval(id);
  }, [lastTimestamp, interval]);

  const hours = Math.floor(secondsLeft / 3600);
  const mins = Math.floor((secondsLeft % 3600) / 60);
  const secs = secondsLeft % 60;

  const pad = (n: number) => String(n).padStart(2, "0");

  if (secondsLeft === 0) {
    return (
      <span className="font-mono text-2xl font-bold text-emerald-400">
        Ready!
      </span>
    );
  }

  return (
    <div className="flex items-baseline gap-1">
      {hours > 0 && (
        <>
          <span className="font-mono text-2xl font-bold text-white">{pad(hours)}</span>
          <span className="text-xs text-zinc-400">h</span>
        </>
      )}
      <span className="font-mono text-2xl font-bold text-white">{pad(mins)}</span>
      <span className="text-xs text-zinc-400">m</span>
      <span className="font-mono text-2xl font-bold text-white">{pad(secs)}</span>
      <span className="text-xs text-zinc-400">s</span>
    </div>
  );
}
