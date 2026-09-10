"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { BaseError, parseUnits } from "viem";
import { useAccount, useWriteContract } from "wagmi";

import { Metric } from "@/components/metric";
import { accountAbi, controllerAbi } from "@/lib/abi";
import { api, type StressResponse, type StressStage } from "@/lib/api";
import {
  MARKET_ADDR,
  RISK_CONTROLLER_ADDRESS,
  TRADING_ACCOUNT_ADDRESS,
} from "@/lib/config";
import { leverageLabel, usd } from "@/lib/format";
import { useViewWallet } from "@/lib/use-view-wallet";

type Step = "idle" | "shocked" | "rejected" | "elevated" | "recovered";

export function RiskScreen() {
  const { wallet } = useViewWallet();
  const { isConnected } = useAccount();
  const qc = useQueryClient();
  const live = useQuery({ queryKey: ["risk", wallet], queryFn: () => api.risk(wallet) });
  const [sitting, setSitting] = useState<StressResponse | null>(null);
  const [step, setStep] = useState<Step>("idle");
  const [probe, setProbe] = useState<string | null>(null);
  const { writeContractAsync, isPending } = useWriteContract();

  const simulate = useMutation({
    mutationFn: () => api.simulateStress(wallet),
    onSuccess: async (data) => {
      setSitting(data);
      setProbe(null);
      try {
        await pushPolicy(data.stages.shock);
      } catch (err) {
        setProbe(err instanceof BaseError ? err.shortMessage : String(err));
      }
      setStep("shocked");
      const reason = await probeTrade(data);
      setProbe(reason);
      if (reason) setStep("rejected");
      await qc.invalidateQueries({ queryKey: ["risk", wallet] });
      await qc.invalidateQueries({ queryKey: ["policy", wallet] });
    },
  });

  async function pushPolicy(stage: StressStage) {
    if (!RISK_CONTROLLER_ADDRESS || !isConnected) return;
    const now = BigInt(Math.floor(Date.now() / 1000));
    const limits = stage.onchain.markets.map((m) => BigInt(m.limit));
    const markets = stage.onchain.markets.map(
      (m) => MARKET_ADDR[m.symbol as keyof typeof MARKET_ADDR],
    );
    await writeContractAsync({
      address: RISK_CONTROLLER_ADDRESS,
      abi: controllerAbi,
      functionName: "applyPolicy",
      args: [
        wallet,
        BigInt(stage.onchain.creditLimit),
        BigInt(stage.onchain.maxLeverage),
        BigInt(stage.onchain.dailyLossLimit),
        now,
        now + 86_400n,
        stage.onchain.riskLevel,
        markets,
        limits,
      ],
    });
  }

  async function probeTrade(data: StressResponse): Promise<string> {
    if (!TRADING_ACCOUNT_ADDRESS || !isConnected) {
      return data.trade.allowed_after_shock
        ? "Python: $20k still allowed (unexpected)"
        : "Python: $20k BTC now exceeds the shocked BTC cap. Contract would revert exposure exceeds position limit.";
    }
    try {
      await writeContractAsync({
        address: TRADING_ACCOUNT_ADDRESS,
        abi: accountAbi,
        functionName: "executeTrade",
        args: [
          MARKET_ADDR.BTC,
          0,
          parseUnits(String(data.trade.size), 6),
          BigInt(data.trade.leverage) * 10n ** 18n,
          parseUnits("60000", 18),
        ],
      });
      return "Trade submitted — unexpected after shock.";
    } catch (err) {
      const message = err instanceof BaseError ? err.shortMessage : String(err);
      return `Onchain reject: ${message}`;
    }
  }

  async function recover(target: "elevated" | "recovered") {
    if (!sitting) return;
    try {
      await pushPolicy(sitting.stages[target]);
      setStep(target);
    } catch (err) {
      setProbe(err instanceof BaseError ? err.shortMessage : String(err));
    }
    await qc.invalidateQueries({ queryKey: ["risk", wallet] });
    await qc.invalidateQueries({ queryKey: ["policy", wallet] });
  }

  const current = live.data;
  const stages = sitting?.stages;

  return (
    <section className="kx-page">
      <header className="kx-page-head">
        <div>
          <p className="kx-kicker">Adaptive risk</p>
          <h1>Risk Center</h1>
        </div>
        <button
          type="button"
          className="kx-btn kx-btn-primary"
          disabled={simulate.isPending || isPending}
          onClick={() => simulate.mutate()}
        >
          {simulate.isPending ? "Simulating…" : "SIMULATE MARKET STRESS"}
        </button>
      </header>

      <p className="kx-lede">
        Injects vol +85%, liquidity −28%, drawdown −12%, correlation +20%. Python
        proposes; the controller writes the policy; the account rejects a $20k BTC
        trade that just worked.
      </p>

      <div className="kx-grid-4">
        <Metric label="Base" value={usd(current?.base_credit)} />
        <Metric
          label="Trader × market"
          value={
            current
              ? `${Number(current.trader_multiplier).toFixed(3)} × ${Number(current.market_multiplier).toFixed(3)}`
              : "—"
          }
        />
        <Metric label="Current credit" value={usd(current?.current_credit)} />
        <Metric label="State" value={current?.risk_level ?? "—"} />
      </div>

      <div className="kx-split">
        <div className="kx-panel">
          <p className="kx-kicker">Sitting</p>
          <ol className="kx-checks">
            <li className={step !== "idle" ? "is-ok" : ""}>
              <span>{step !== "idle" ? "DONE" : "WAIT"}</span>
              <span>Approve under NORMAL</span>
              <span className="kx-muted">{usd(stages?.normal.current_credit)}</span>
            </li>
            <li className={step === "shocked" || step === "rejected" || step === "elevated" || step === "recovered" ? "is-ok" : ""}>
              <span>{["shocked", "rejected", "elevated", "recovered"].includes(step) ? "DONE" : "WAIT"}</span>
              <span>HIGH shock onchain</span>
              <span className="kx-muted">{usd(stages?.shock.current_credit)}</span>
            </li>
            <li className={step === "rejected" || step === "elevated" || step === "recovered" ? "is-bad" : ""}>
              <span>{["rejected", "elevated", "recovered"].includes(step) ? "REVERT" : "WAIT"}</span>
              <span>$20k BTC rejected</span>
              <span className="kx-muted">{sitting?.trade.allowed_after_shock ? "allowed" : "over BTC cap"}</span>
            </li>
            <li className={step === "elevated" || step === "recovered" ? "is-ok" : ""}>
              <span>{step === "elevated" || step === "recovered" ? "DONE" : "WAIT"}</span>
              <span>ELEVATED unwind</span>
              <span className="kx-muted">{usd(stages?.elevated.current_credit)}</span>
            </li>
            <li className={step === "recovered" ? "is-ok" : ""}>
              <span>{step === "recovered" ? "DONE" : "WAIT"}</span>
              <span>NORMAL restored</span>
              <span className="kx-muted">{usd(stages?.recovered.current_credit)}</span>
            </li>
          </ol>
          {simulate.error ? <p className="kx-err">{String(simulate.error)}</p> : null}
          {probe ? <p className="kx-err">{probe}</p> : null}
          <div className="kx-row">
            <button
              type="button"
              className="kx-btn"
              disabled={!sitting || isPending}
              onClick={() => void recover("elevated")}
            >
              Recover → ELEVATED
            </button>
            <button
              type="button"
              className="kx-btn kx-btn-primary"
              disabled={!sitting || isPending}
              onClick={() => void recover("recovered")}
            >
              Recover → NORMAL
            </button>
          </div>
          {!RISK_CONTROLLER_ADDRESS ? (
            <p className="kx-hint">
              Controller unset. Python sitting is live; Foundry StressTest applies the
              same policies onchain.
            </p>
          ) : !isConnected ? (
            <p className="kx-hint">Connect the controller key to push applyPolicy.</p>
          ) : null}
        </div>
        <div className="kx-panel">
          <p className="kx-kicker">Policy path</p>
          <table className="kx-table">
            <thead>
              <tr>
                <th></th>
                <th className="kx-num">NORMAL</th>
                <th className="kx-num">HIGH</th>
                <th className="kx-num">ELEVATED</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Credit</td>
                <td className="kx-num">{usd(stages?.normal.policy.creditLimit ?? current?.policy.creditLimit)}</td>
                <td className="kx-num">{usd(stages?.shock.policy.creditLimit)}</td>
                <td className="kx-num">{usd(stages?.elevated.policy.creditLimit)}</td>
              </tr>
              <tr>
                <td>Leverage</td>
                <td className="kx-num">{leverageLabel(stages?.normal.policy.maxLeverage ?? current?.policy.maxLeverage)}</td>
                <td className="kx-num">{leverageLabel(stages?.shock.policy.maxLeverage)}</td>
                <td className="kx-num">{leverageLabel(stages?.elevated.policy.maxLeverage)}</td>
              </tr>
              <tr>
                <td>BTC</td>
                <td className="kx-num">{usd(stages?.normal.policy.markets.BTC ?? current?.policy.markets.BTC)}</td>
                <td className="kx-num">{usd(stages?.shock.policy.markets.BTC)}</td>
                <td className="kx-num">{usd(stages?.elevated.policy.markets.BTC)}</td>
              </tr>
              <tr>
                <td>Level</td>
                <td className="kx-num">{stages?.normal.risk_level ?? current?.risk_level ?? "—"}</td>
                <td className="kx-num">{stages?.shock.risk_level ?? "—"}</td>
                <td className="kx-num">{stages?.elevated.risk_level ?? "—"}</td>
              </tr>
            </tbody>
          </table>
          <p className="kx-hint">
            {sitting
              ? `${usd(sitting.stages.shock.current_credit)} → ${usd(sitting.stages.elevated.current_credit)} → ${usd(sitting.stages.recovered.current_credit)}`
              : "Run SIMULATE MARKET STRESS to walk HIGH → ELEVATED → NORMAL."}
          </p>
        </div>
      </div>
    </section>
  );
}
