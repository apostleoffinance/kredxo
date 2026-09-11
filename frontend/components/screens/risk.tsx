"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { BaseError, parseUnits } from "viem";
import { useAccount, useChainId, useWriteContract } from "wagmi";

import { ConnectHint } from "@/components/connect-hint";
import { CreditState } from "@/components/credit-state";
import { RiskBadge } from "@/components/risk-badge";
import { accountAbi, controllerAbi } from "@/lib/abi";
import { api, type StressResponse, type StressStage } from "@/lib/api";
import { capOnchainPolicy } from "@/lib/checks";
import { DEMO_WALLET, MARKET_ADDR } from "@/lib/config";
import { leverageLabel, usd } from "@/lib/format";
import { MONAD_TESTNET_ID } from "@/lib/monad";
import { useCreditState } from "@/lib/use-credit-state";

type Step = "idle" | "shocked" | "rejected" | "elevated" | "recovered";
const PATH_COLS = ["NORMAL", "HIGH", "ELEVATED"] as const;
type PathCol = (typeof PATH_COLS)[number];

function pathCurrent(step: Step): PathCol {
  if (step === "elevated") return "ELEVATED";
  if (step === "shocked" || step === "rejected") return "HIGH";
  return "NORMAL";
}

function PolicyPathRow({
  label,
  values,
  current,
  header,
}: {
  label: string;
  values: [string, string, string];
  current: PathCol;
  header?: boolean;
}) {
  return (
    <div className={header ? "kx-policy-row kx-policy-header" : "kx-policy-row"}>
      <span className="kx-policy-label">{label}</span>
      {PATH_COLS.map((col, i) => (
        <span
          key={col}
          className={current === col ? "kx-policy-value is-current" : "kx-policy-value"}
        >
          {values[i]}
        </span>
      ))}
    </div>
  );
}

export function RiskScreen() {
  const s = useCreditState();
  const trader = (s.creditWallet ?? DEMO_WALLET) as `0x${string}`;
  const { isConnected } = useAccount();
  const chainId = useChainId();
  const kredxo = s.kredxo;
  const qc = useQueryClient();
  const [sitting, setSitting] = useState<StressResponse | null>(null);
  const [step, setStep] = useState<Step>("idle");
  const [probe, setProbe] = useState<string | null>(null);
  const { writeContractAsync, isPending } = useWriteContract();

  const simulate = useMutation({
    mutationFn: () => api.simulateStress(trader),
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
      await qc.invalidateQueries({ queryKey: ["risk", trader] });
      await qc.invalidateQueries({ queryKey: ["policy", trader] });
      await s.refetchOnchain();
    },
  });

  async function pushPolicy(stage: StressStage) {
    const controller = kredxo.riskController;
    if (!controller || !isConnected || chainId !== MONAD_TESTNET_ID) return;
    const capped = capOnchainPolicy(stage.onchain, s.issued || s.traderAllocated);
    const now = BigInt(Math.floor(Date.now() / 1000));
    const limits = capped.markets.map((m) => BigInt(m.limit));
    const markets = capped.markets.map(
      (m) => MARKET_ADDR[m.symbol as keyof typeof MARKET_ADDR],
    );
    await writeContractAsync({
      chainId: MONAD_TESTNET_ID,
      address: controller,
      abi: controllerAbi,
      functionName: "applyPolicy",
      args: [
        trader,
        BigInt(capped.creditLimit),
        BigInt(capped.maxLeverage),
        BigInt(capped.dailyLossLimit),
        now,
        now + BigInt(86_400),
        capped.riskLevel,
        markets,
        limits,
      ],
    });
  }

  async function probeTrade(data: StressResponse): Promise<string> {
    const accountAddr = kredxo.tradingAccount;
    if (!accountAddr || !isConnected || chainId !== MONAD_TESTNET_ID) {
      return data.trade.allowed_after_shock
        ? `${usd(data.trade.size)} still allowed after shock (unexpected)`
        : `${usd(data.trade.size)} BTC now exceeds the shocked BTC cap.`;
    }
    try {
      await writeContractAsync({
        chainId: MONAD_TESTNET_ID,
        address: accountAddr,
        abi: accountAbi,
        functionName: "executeTrade",
        args: [
          MARKET_ADDR.BTC,
          0,
          parseUnits(String(data.trade.size), 6),
          BigInt(data.trade.leverage) * BigInt(10) ** BigInt(18),
          parseUnits("60000", 18),
        ],
      });
      return "Trade submitted — unexpected after shock.";
    } catch (err) {
      const message = err instanceof BaseError ? err.shortMessage : String(err);
      return `Rejected: ${message}`;
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
    await qc.invalidateQueries({ queryKey: ["risk", trader] });
    await qc.invalidateQueries({ queryKey: ["policy", trader] });
    await s.refetchOnchain();
  }

  const live = s.risk.data;
  const stages = sitting?.stages;
  const normalCredit = stages?.normal.current_credit ?? live?.current_credit;
  const shockCredit = stages?.shock.current_credit;
  const probeSize = sitting?.trade.size ?? 20_000;
  const currentCol = pathCurrent(step);

  return (
    <section className="kx-page">
      <CreditState />
      <header className="kx-page-head">
        <div>
          <p className="kx-kicker">Adaptive risk</p>
          <h1>Risk</h1>
          <p className="kx-lede">
            Volatility, liquidity, and correlation are simulated. The resulting policy write and
            trade rejection are Monad transactions.
          </p>
          {!isConnected ? <ConnectHint to="apply policy onchain" /> : null}
        </div>
        <button
          type="button"
          className="kx-btn kx-btn-primary"
          disabled={simulate.isPending || isPending}
          onClick={() => simulate.mutate()}
        >
          {simulate.isPending ? "Simulating…" : "Simulate market stress"}
        </button>
      </header>

      <ol className="kx-flow">
        <li className={step === "idle" ? "is-now" : "is-done"}>
          <span>Before</span>
          <strong>NORMAL</strong>
        </li>
        <li className={step === "shocked" ? "is-now" : ["rejected", "elevated", "recovered"].includes(step) ? "is-done" : ""}>
          <span>Stress</span>
          <strong>HIGH</strong>
        </li>
        <li className={step === "rejected" ? "is-now is-block" : ["elevated", "recovered"].includes(step) ? "is-done" : ""}>
          <span>Trade</span>
          <strong>Blocked</strong>
        </li>
        <li className={step === "elevated" ? "is-now" : step === "recovered" ? "is-done" : ""}>
          <span>Unwind</span>
          <strong>ELEVATED</strong>
        </li>
        <li className={step === "recovered" ? "is-now is-done" : ""}>
          <span>Restored</span>
          <strong>NORMAL</strong>
        </li>
      </ol>

      <div className="kx-split">
        <div className="kx-panel">
          {step === "idle" ? (
            <>
              <p className="kx-kicker">Market conditions</p>
              <table className="kx-table">
                <tbody>
                  <tr>
                    <td>Volatility</td>
                    <td className="kx-num">NORMAL</td>
                  </tr>
                  <tr>
                    <td>Liquidity</td>
                    <td className="kx-num">NORMAL</td>
                  </tr>
                  <tr>
                    <td>Correlation</td>
                    <td className="kx-num">NORMAL</td>
                  </tr>
                </tbody>
              </table>
              <p className="kx-kicker" style={{ marginTop: "1rem" }}>
                Your credit
              </p>
              <p className="kx-account-issued">{usd(s.issued)}</p>
              <p className="kx-hint">
                Issued onchain. Recommended {usd(s.recommended)} is eligibility, not inventory.
              </p>
            </>
          ) : null}

          {step === "shocked" || step === "rejected" ? (
            <>
              <p className="kx-kicker">Market stress detected</p>
              <table className="kx-table">
                <tbody>
                  <tr>
                    <td>BTC volatility</td>
                    <td className="kx-num">+85%</td>
                  </tr>
                  <tr>
                    <td>Liquidity</td>
                    <td className="kx-num">−28%</td>
                  </tr>
                  <tr>
                    <td>Correlation</td>
                    <td className="kx-num">+20%</td>
                  </tr>
                </tbody>
              </table>
              <p className="kx-kicker" style={{ marginTop: "1rem" }}>
                Credit adjusted
              </p>
              <p className="kx-account-issued">
                {usd(normalCredit)} → {usd(shockCredit)}
              </p>
              <p className="kx-hint">
                Trader × market {s.traderMult?.toFixed(3) ?? "—"} × {s.marketMult?.toFixed(3) ?? "—"}
              </p>
            </>
          ) : null}

          {step === "elevated" || step === "recovered" ? (
            <>
              <p className="kx-kicker">{step === "recovered" ? "Market recovered" : "Unwind"}</p>
              <p className="kx-account-issued">
                {usd(shockCredit)} → {usd(stages?.[step].current_credit)}
              </p>
              <p className="kx-hint">
                {step === "recovered"
                  ? "Credit and caps restore with the market."
                  : "Policy eases from HIGH to ELEVATED."}
              </p>
            </>
          ) : null}

          {step === "rejected" ? (
            <div className="kx-block-card">
              <p className="kx-kicker">Blocked</p>
              <p>
                Attempted {usd(probeSize)} BTC. Credit policy does not permit this position under
                current risk.
              </p>
              {probe ? <p className="kx-err">{probe}</p> : null}
            </div>
          ) : null}
          {probe && step !== "rejected" ? <p className="kx-err">{probe}</p> : null}

          {simulate.error ? <p className="kx-err">{String(simulate.error)}</p> : null}

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
              Restore market
            </button>
          </div>
          {!kredxo.riskController || chainId !== MONAD_TESTNET_ID ? (
            <p className="kx-hint">
              {chainId !== MONAD_TESTNET_ID
                ? "Switch to Monad Testnet to apply the new policy."
                : "Policy control is not available on this network."}
            </p>
          ) : !isConnected ? (
            <ConnectHint to="apply the new policy" />
          ) : (
            <p className="kx-hint">
              applyPolicy is operator-gated. After stress, try an over-limit size on Execute — the
              account reverts.
            </p>
          )}
        </div>

        <div className="kx-panel">
          <div className="kx-policy-head">
            <p className="kx-kicker">Policy path</p>
            <RiskBadge state={s.riskLevel} />
          </div>
          <div className="kx-policy-path" role="table" aria-label="Policy path">
            <PolicyPathRow
              header
              label=""
              current={currentCol}
              values={["NORMAL", "HIGH", "ELEVATED"]}
            />
            <PolicyPathRow
              label="Credit"
              current={currentCol}
              values={[
                usd(stages?.normal.policy.creditLimit ?? live?.policy.creditLimit),
                usd(stages?.shock.policy.creditLimit),
                usd(stages?.elevated.policy.creditLimit),
              ]}
            />
            <PolicyPathRow
              label="Leverage"
              current={currentCol}
              values={[
                leverageLabel(stages?.normal.policy.maxLeverage ?? live?.policy.maxLeverage),
                leverageLabel(stages?.shock.policy.maxLeverage),
                leverageLabel(stages?.elevated.policy.maxLeverage),
              ]}
            />
            <PolicyPathRow
              label="BTC"
              current={currentCol}
              values={[
                usd(stages?.normal.policy.markets.BTC ?? live?.policy.markets.BTC),
                usd(stages?.shock.policy.markets.BTC),
                usd(stages?.elevated.policy.markets.BTC),
              ]}
            />
            <PolicyPathRow
              label="Level"
              current={currentCol}
              values={[
                stages?.normal.risk_level ?? live?.risk_level ?? "—",
                stages?.shock.risk_level ?? "—",
                stages?.elevated.risk_level ?? "—",
              ]}
            />
          </div>
          <p className="kx-hint">Risk model above. Account limits remain vault-capped.</p>
        </div>
      </div>
    </section>
  );
}
