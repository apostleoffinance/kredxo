"use client";

import { useBlockNumber, useChainId } from "wagmi";

import { monadNetwork } from "@/lib/monad";

const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

export function InfrastructureStatus() {
  const chainId = useChainId();
  const { data: blockNumber, isError, isLoading } = useBlockNumber({
    watch: true,
  });

  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col justify-center gap-10 px-6 py-16">
      <header className="space-y-3">
        <p className="text-xs tracking-[0.25em] text-zinc-500">KREDXO</p>
        <h1 className="text-4xl font-semibold tracking-tight">
          Adaptive trading credit
        </h1>
        <p className="max-w-xl text-zinc-400">
          Phase 1 infrastructure. Credit Intelligence → Adaptive Risk →
          Programmable Policy → Execution → Reassessment.
        </p>
      </header>

      <section className="grid gap-4 rounded-xl border border-zinc-800 bg-zinc-950/60 p-6 sm:grid-cols-2">
        <StatusRow label="Phase" value="1 — Repository & infrastructure" />
        <StatusRow label="Network" value={chainId === 143 ? "Monad Mainnet" : "Monad Testnet"} />
        <StatusRow label="Chain ID" value={String(chainId || monadNetwork.chainId)} />
        <StatusRow
          label="RPC"
          value={monadNetwork.rpcUrl.replace(/^https?:\/\//, "")}
        />
        <StatusRow
          label="Head"
          value={
            isLoading
              ? "connecting…"
              : isError
                ? "RPC unavailable"
                : blockNumber !== undefined
                  ? `#${blockNumber.toString()}`
                  : "—"
          }
        />
        <StatusRow
          label="Finality"
          value={`${monadNetwork.blockFrequencyMs}ms blocks · ${monadNetwork.finalityMs}ms`}
        />
        <StatusRow label="API" value={apiUrl} />
        <StatusRow label="Enforcement" value="Credit adapts. Policy enforces." />
      </section>

      <p className="text-sm text-zinc-500">
        Vault accounting, credit accounts, and the risk engine are intentionally
        not in this phase.
      </p>
    </main>
  );
}

function StatusRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="space-y-1">
      <p className="text-[11px] uppercase tracking-widest text-zinc-500">{label}</p>
      <p className="font-mono text-sm text-zinc-100">{value}</p>
    </div>
  );
}
