"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import ReactECharts from "echarts-for-react";
import { useMemo } from "react";

import { Metric } from "@/components/metric";
import { api } from "@/lib/api";
import { usd } from "@/lib/format";
import { useViewWallet } from "@/lib/use-view-wallet";

export function ProfileScreen() {
  const { wallet } = useViewWallet();
  const qc = useQueryClient();
  const credit = useQuery({ queryKey: ["credit", wallet], queryFn: () => api.credit(wallet) });
  const trades = useQuery({ queryKey: ["trades", wallet], queryFn: () => api.trades(wallet) });
  const request = useMutation({
    mutationFn: () => api.requestCredit(wallet),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["credit", wallet] });
      void qc.invalidateQueries({ queryKey: ["risk", wallet] });
      void qc.invalidateQueries({ queryKey: ["policy", wallet] });
    },
  });

  const curve = useMemo(() => {
    const rows = trades.data?.trades ?? [];
    let run = 0;
    return rows.map((t) => {
      run += Number(t.pnl ?? 0);
      return run;
    });
  }, [trades.data]);

  const c = credit.data;
  return (
    <section className="kx-page">
      <header className="kx-page-head">
        <div>
          <p className="kx-kicker">Credit intelligence</p>
          <h1>Profile</h1>
        </div>
        <button
          type="button"
          className="kx-btn kx-btn-primary"
          disabled={request.isPending}
          onClick={() => request.mutate()}
        >
          {request.isPending ? "Evaluating…" : "Request credit"}
        </button>
      </header>

      <div className="kx-grid-4">
        <Metric label="Score" value={c ? String(c.score) : "—"} />
        <Metric label="Tier" value={c?.tier ?? "—"} />
        <Metric label="Base credit" value={usd(c?.base_credit)} hint="Ceiling before multipliers" />
        <Metric label="Trades" value={String(trades.data?.count ?? "—")} />
      </div>

      <div className="kx-split">
        <div className="kx-panel">
          <p className="kx-kicker">Components</p>
          <table className="kx-table">
            <tbody>
              {c
                ? Object.entries(c.components).map(([key, value]) => (
                    <tr key={key}>
                      <td>{key.replaceAll("_", " ")}</td>
                      <td className="kx-num">{Number(value).toFixed(1)}</td>
                    </tr>
                  ))
                : null}
            </tbody>
          </table>
        </div>
        <div className="kx-panel">
          <p className="kx-kicker">History</p>
          <table className="kx-table">
            <tbody>
              <tr>
                <td>Volume</td>
                <td className="kx-num">{usd(trades.data?.volume)}</td>
              </tr>
              <tr>
                <td>Realized PnL</td>
                <td className="kx-num">{usd(trades.data?.realized_pnl)}</td>
              </tr>
              <tr>
                <td>Win rate</td>
                <td className="kx-num">
                  {c ? `${(Number(c.metrics.win_rate) * 100).toFixed(1)}%` : "—"}
                </td>
              </tr>
              <tr>
                <td>Max drawdown</td>
                <td className="kx-num">
                  {c ? `${(Number(c.metrics.max_drawdown) * 100).toFixed(1)}%` : "—"}
                </td>
              </tr>
              <tr>
                <td>Sharpe</td>
                <td className="kx-num">{c ? Number(c.metrics.sharpe).toFixed(2) : "—"}</td>
              </tr>
            </tbody>
          </table>
          {curve.length > 1 ? (
            <ReactECharts
              style={{ height: 160, marginTop: 12 }}
              option={{
                backgroundColor: "transparent",
                grid: { left: 8, right: 8, top: 8, bottom: 8 },
                xAxis: { type: "category", show: false, data: curve.map((_, i) => i) },
                yAxis: { type: "value", show: false },
                series: [
                  {
                    type: "line",
                    data: curve,
                    showSymbol: false,
                    lineStyle: { color: "#a1a1aa", width: 1.5 },
                    areaStyle: { color: "rgba(161,161,170,0.08)" },
                  },
                ],
              }}
            />
          ) : null}
        </div>
      </div>
      {request.data ? (
        <p className="kx-ok">
          Request stored. Score {String((request.data as { score?: number }).score ?? "")} ·
          current credit follows Risk.
        </p>
      ) : null}
      {request.error ? <p className="kx-err">{String(request.error)}</p> : null}
    </section>
  );
}

