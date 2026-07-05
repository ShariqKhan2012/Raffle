import { Header } from "@/components/Header";
import { RaffleCard } from "@/components/RaffleCard";

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col">
      <Header />
      <main className="flex flex-1 flex-col items-center px-6 py-16">
        {/* Hero */}
        <div className="mb-12 text-center">
          <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-violet-500/30 bg-violet-500/10 px-4 py-1.5 text-xs font-medium text-violet-300">
            <span className="h-1.5 w-1.5 rounded-full bg-violet-400" />
            Chainlink VRF v2.5 · Verifiably Random
          </div>
          <h2 className="mt-2 text-4xl font-bold tracking-tight text-white sm:text-5xl">
            On-Chain Raffle
          </h2>
          <p className="mt-4 max-w-md text-base text-zinc-400">
            Pay the entry fee, get a ticket. Chainlink Automation picks a provably fair winner
            when the interval expires.
          </p>
        </div>

        <RaffleCard />

        {/* How it works */}
        <section className="mt-20 w-full max-w-3xl">
          <h3 className="mb-6 text-lg font-semibold text-white">How it works</h3>
          <div className="grid gap-4 sm:grid-cols-3">
            {[
              {
                step: "1",
                title: "Enter",
                desc: "Pay the entry fee in ETH. Your address is added to the player pool.",
              },
              {
                step: "2",
                title: "Wait",
                desc: "Chainlink Automation monitors the contract and triggers a draw after the interval.",
              },
              {
                step: "3",
                title: "Win",
                desc: "A VRF random number selects the winner. The entire prize pool is sent instantly.",
              },
            ].map((item) => (
              <div
                key={item.step}
                className="rounded-2xl border border-white/10 bg-white/5 p-5"
              >
                <div className="mb-3 flex h-8 w-8 items-center justify-center rounded-lg bg-violet-600 text-sm font-bold">
                  {item.step}
                </div>
                <h4 className="mb-1 font-semibold text-white">{item.title}</h4>
                <p className="text-sm text-zinc-400">{item.desc}</p>
              </div>
            ))}
          </div>
        </section>
      </main>

      <footer className="border-t border-white/10 py-6 text-center text-xs text-zinc-600">
        Built with Foundry · Chainlink VRF v2.5 · Next.js
      </footer>
    </div>
  );
}
