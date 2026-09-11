"use client";

import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { useChainId, useReadContract } from "wagmi";

import { Metric } from "@/components/metric";
import { RiskBadge } from "@/components/risk-badge";
import { accountAbi } from "@/lib/abi";
import { api } from "@/lib/api";
import { EXPLORER_URL, DEMO_WALLET, explorerAddress, explorerTx } from "@/lib/config";
import { compact, usd } from "@/lib/format";
import { kredxoOn } from "@/lib/networks";

const STEPS = [
  { href: "/market", label: "LP deposits USDC", detail: "Vault TVL is live inventory" },
  { href: "/profile", label: "Score 87 / ADVANCED", detail: "History recommends $50k from 120 trades" },
  { href: "/account", label: "Credit issued", detail: "Issued credit never exceeds deposit; no withdrawal" },
  { href: "/trade", label: "BTC trade inside policy", detail: "Policy approves; the account is the authority" },
  { href: "/risk", label: "Simulate market stress", detail: "Risk rises; policy tightens to HIGH" },
  { href: "/risk", label: "Over-limit BTC rejected", detail: "Rejection is in the account, not this screen" },
  { href: "/risk", label: "Recover ELEVATED → NORMAL", detail: "Credit and caps restore with the market" },
];

function units6(raw?: string) {
  if (!raw) return undefined;
  return Number(raw) / 1e6;
}

export function DemoScreen() {
  const wallet = DEMO_WALLET;
  const chainId = useChainId();
  const accountAddr = kredxoOn(chainId).tradingAccount;
  const demo = useQuery({ queryKey: ["demo"], queryFn: api.demo });
  const credit = useQuery({ queryKey: ["credit", wallet], queryFn: () => api.credit(wallet) });
  const risk = useQuery({ queryKey: ["risk", wallet], queryFn: () => api.risk(wallet) });
  const onchainLimit = useReadContract({
    address: accountAddr || undefined,
    abi: accountAbi,
    functionName: "creditLimit",
    query: { enabled: Boolean(accountAddr) },
  });

  const packet = demo.data;
  const liveLimit =
    onchainLimit.data !== undefined ? Number(onchainLimit.data) / 1e6 : units6(packet?.seed?.credit);
  const contracts = packet?.contracts ?? {};
  const rows: [string, string | null | undefined][] = [
    ["USDC", contracts.usdc],
    ["Vault", contracts.vault],
    ["Trading account", contracts.tradingAccount],
    ["Risk control", contracts.controller],
    ["Risk policy", contracts.policy],
    ["Settlement", contracts.settlement],
    ["Registry", contracts.registry],
  ];

  return (
    <section className="kx-page">
      <header className="kx-page-head">
        <div>
          <p className="kx-kicker is-accent">Live testnet</p>
          <h1>Sitting</h1>
        </div>
      </header>

      <div className="kx-state">
        <div className="kx-state-head">
          <div>
            <p className="kx-kicker">Credit state</p>
            <p className="kx-hint">Session {compact(packet?.demo_wallet ?? wallet)}</p>
          </div>
          <RiskBadge state={risk.data?.risk_level} />
        </div>
        <div className="kx-grid-4">
          <Metric label="Score" value={credit.data ? String(credit.data.score) : "—"} hint={credit.data?.tier} />
          <Metric
            label="Recommended credit"
            value={usd(credit.data?.base_credit)}
            hint="From verified trade history"
            tone="intel"
          />
          <Metric
            label="Issued credit"
            value={usd(liveLimit)}
            hint="Enforced capacity; never exceeds deposit"
            tone="enforce"
          />
          <Metric
            label="BTC cap"
            value={usd(units6(packet?.seed?.btcLimit))}
            hint="Live policy after seed"
          />
        </div>
        <p className="kx-callout">
          History scores this book at <span className="is-intel">{usd(credit.data?.base_credit)}</span>.
          This sitting issues <span className="is-enforce">{usd(liveLimit)}</span> — issued credit never
          exceeds the LP deposit.
        </p>
      </div>

      <div>
        <p className="kx-kicker">Sitting</p>
        <div className="kx-sit-row">
          {STEPS.map((step, i) => (
            <Link key={step.label} href={step.href} className="kx-sit-card">
              <span className="kx-sit-num">{String(i + 1).padStart(2, "0")}</span>
              <strong>{step.label}</strong>
              <span>{step.detail}</span>
            </Link>
          ))}
        </div>
        <p className="kx-hint">
          Reference path: $100k LP → $50k credit → $10k BTC approved → $20k rejected.
          This sitting is $20 / $20 / $10. Same rule.
        </p>
      </div>

      <div className="kx-split">
        <div className="kx-panel">
          <p className="kx-kicker">Live seed</p>
          <table className="kx-table">
            <tbody>
              <tr>
                <td>Trader</td>
                <td className="kx-num kx-mono">{compact(packet?.demo_wallet ?? wallet)}</td>
              </tr>
              <tr>
                <td>LP / admin</td>
                <td className="kx-num kx-mono">{compact(packet?.lp ?? "")}</td>
              </tr>
              <tr>
                <td>Deposit</td>
                <td className="kx-num">
                  {packet?.seed?.txs.deposit ? (
                    <a className="kx-inline-link" href={explorerTx(packet.seed.txs.deposit)} target="_blank" rel="noreferrer">
                      {usd(units6(packet.seed.deposited))}
                    </a>
                  ) : (
                    usd(units6(packet?.seed?.deposited))
                  )}
                </td>
              </tr>
              <tr>
                <td>Credit issued</td>
                <td className="kx-num">
                  {packet?.seed?.txs.allocateCredit ? (
                    <a
                      className="kx-inline-link"
                      href={explorerTx(packet.seed.txs.allocateCredit)}
                      target="_blank"
                      rel="noreferrer"
                    >
                      {usd(units6(packet.seed.credit))}
                    </a>
                  ) : (
                    "—"
                  )}
                </td>
              </tr>
              <tr>
                <td>Monad</td>
                <td className="kx-num">
                  {packet?.network.tps.toLocaleString()} TPS · {packet?.network.block_frequency_ms ?? 300}ms
                  blocks · {packet?.network.finality_ms ?? 600}ms finality
                </td>
              </tr>
            </tbody>
          </table>
          <p className="kx-hint">
            This sitting uses the internal book. Perpl and Kuru are not live. Credit cannot be
            withdrawn.{" "}
            <a className="kx-inline-link" href={EXPLORER_URL} target="_blank" rel="noreferrer">
              MonadVision
            </a>
          </p>
        </div>
        <div className="kx-panel">
          <p className="kx-kicker">Addresses</p>
          <table className="kx-table">
            <tbody>
              {rows.map(([label, addr]) => (
                <tr key={label}>
                  <td>{label}</td>
                  <td className="kx-num">
                    {addr ? (
                      <a className="kx-inline-link kx-mono" href={explorerAddress(addr)} target="_blank" rel="noreferrer">
                        {addr}
                      </a>
                    ) : (
                      "—"
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
