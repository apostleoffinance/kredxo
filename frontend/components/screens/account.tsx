"use client";

import { useQuery } from "@tanstack/react-query";
import { useReadContract } from "wagmi";

import { Metric } from "@/components/metric";
import { accountAbi } from "@/lib/abi";
import { api } from "@/lib/api";
import { TRADING_ACCOUNT_ADDRESS } from "@/lib/config";
import { leverageLabel, usd } from "@/lib/format";
import { useViewWallet } from "@/lib/use-view-wallet";

function riskTone(level?: string) {
  if (level === "LOW" || level === "NORMAL") return "good" as const;
  if (level === "ELEVATED") return "warn" as const;
  if (level === "HIGH" || level === "CRITICAL") return "bad" as const;
  return "default" as const;
}

export function AccountScreen() {
  const { wallet } = useViewWallet();
  const risk = useQuery({ queryKey: ["risk", wallet], queryFn: () => api.risk(wallet) });
  const policy = useQuery({ queryKey: ["policy", wallet], queryFn: () => api.policy(wallet) });
  const positions = useQuery({
    queryKey: ["positions", wallet],
    queryFn: () => api.positions(wallet),
  });
  const usedOnchain = useReadContract({
    address: TRADING_ACCOUNT_ADDRESS || undefined,
    abi: accountAbi,
    functionName: "usedCredit",
    query: { enabled: Boolean(TRADING_ACCOUNT_ADDRESS) },
  });

  const current = Number(risk.data?.current_credit ?? 0);
  const used = usedOnchain.data !== undefined ? Number(usedOnchain.data) / 1e6 : 0;
  const available = Math.max(current - used, 0);
  const p = policy.data?.policy ?? risk.data?.policy;

  return (
    <section className="kx-page">
      <header className="kx-page-head">
        <div>
          <p className="kx-kicker">Credit account</p>
          <h1>Account</h1>
        </div>
        <p className="kx-lede">
          Capacity is authorized credit. Utilization is drawn USDC inside the account.
        </p>
      </header>

      <div className="kx-grid-4">
        <Metric label="Current credit" value={usd(current)} hint={`Base ${usd(risk.data?.base_credit)}`} />
        <Metric
          label="Used"
          value={usd(used)}
          hint={TRADING_ACCOUNT_ADDRESS ? "Onchain usedCredit" : "No account deployed"}
        />
        <Metric label="Available" value={usd(available)} />
        <Metric
          label="Risk"
          value={risk.data?.risk_level ?? "—"}
          tone={riskTone(risk.data?.risk_level)}
        />
      </div>

      <div className="kx-split">
        <div className="kx-panel">
          <p className="kx-kicker">Live policy</p>
          <table className="kx-table">
            <tbody>
              <tr>
                <td>Credit limit</td>
                <td className="kx-num">{usd(p?.creditLimit)}</td>
              </tr>
              <tr>
                <td>Max leverage</td>
                <td className="kx-num">{leverageLabel(p?.maxLeverage)}</td>
              </tr>
              <tr>
                <td>Daily loss</td>
                <td className="kx-num">{usd(p?.dailyLossLimit)}</td>
              </tr>
              <tr>
                <td>BTC</td>
                <td className="kx-num">{usd(p?.markets.BTC)}</td>
              </tr>
              <tr>
                <td>ETH</td>
                <td className="kx-num">{usd(p?.markets.ETH)}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div className="kx-panel">
          <p className="kx-kicker">Open positions</p>
          {positions.data?.positions.length ? (
            <p>{positions.data.positions.length} open</p>
          ) : (
            <p className="kx-hint">None. Endpoint is live; the indexer has no open legs.</p>
          )}
          <p className="kx-hint">
            Multipliers {risk.data ? Number(risk.data.trader_multiplier).toFixed(3) : "—"} ×{" "}
            {risk.data ? Number(risk.data.market_multiplier).toFixed(3) : "—"}
          </p>
        </div>
      </div>
    </section>
  );
}
