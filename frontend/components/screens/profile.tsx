"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import ReactECharts from "echarts-for-react";
import { useEffect, useMemo, useState } from "react";
import { BaseError, parseUnits } from "viem";
import { useAccount, useChainId, useWriteContract } from "wagmi";

import { ConnectHint } from "@/components/connect-hint";
import { CreditState } from "@/components/credit-state";
import { Metric } from "@/components/metric";
import { isOperator } from "@/lib/actors";
import { controllerAbi, vaultAbi } from "@/lib/abi";
import { api } from "@/lib/api";
import { capOnchainPolicy } from "@/lib/checks";
import { DEMO_WALLET, MARKET_ADDR } from "@/lib/config";
import { compact, usd } from "@/lib/format";
import { MONAD_TESTNET_ID } from "@/lib/monad";
import { readTheme, THEME_EVENT, type Theme } from "@/lib/theme";
import { useCreditState } from "@/lib/use-credit-state";
import { useViewWallet } from "@/lib/use-view-wallet";

export function ProfileScreen() {
  const { wallet, isConnected } = useViewWallet();
  const { address } = useAccount();
  const s = useCreditState();
  const chainId = useChainId();
  const qc = useQueryClient();
  const operator = isOperator(address);
  const credit = useQuery({
    queryKey: ["credit", s.creditWallet],
    queryFn: () => api.credit(s.creditWallet as string),
    enabled: Boolean(s.creditWallet),
  });
  const trades = useQuery({
    queryKey: ["trades", s.creditWallet],
    queryFn: () => api.trades(s.creditWallet as string),
    enabled: Boolean(s.creditWallet),
  });
  const { writeContractAsync, isPending, error } = useWriteContract();
  const [issueNote, setIssueNote] = useState<string | null>(null);
  const request = useMutation({
    mutationFn: () => api.requestCredit(s.creditWallet as string),
    onSuccess: async (data) => {
      void qc.invalidateQueries({ queryKey: ["credit", s.creditWallet] });
      void qc.invalidateQueries({ queryKey: ["risk", s.creditWallet] });
      void qc.invalidateQueries({ queryKey: ["policy", s.creditWallet] });
      if (!operator || chainId !== MONAD_TESTNET_ID) {
        setIssueNote(
          "Eligibility stored. Issuance is operator-gated and capped by available vault liquidity.",
        );
        return;
      }
      const vault = s.kredxo.vault;
      const controller = s.kredxo.riskController;
      if (!vault || !controller) return;
      const room = s.availableLiquidity;
      if (room <= 0) {
        setIssueNote("No available liquidity to allocate. An LP must supply first.");
        return;
      }
      try {
        const amount = parseUnits(String(room.toFixed(6)), 6);
        await writeContractAsync({
          chainId: MONAD_TESTNET_ID,
          address: vault,
          abi: vaultAbi,
          functionName: "allocateCredit",
          args: [DEMO_WALLET, amount],
        });
        const issuedUsd = s.traderAllocated + room;
        const capped = capOnchainPolicy(data.onchain, issuedUsd);
        const now = BigInt(Math.floor(Date.now() / 1000));
        await writeContractAsync({
          chainId: MONAD_TESTNET_ID,
          address: controller,
          abi: controllerAbi,
          functionName: "applyPolicy",
          args: [
            DEMO_WALLET,
            BigInt(capped.creditLimit),
            BigInt(capped.maxLeverage),
            BigInt(capped.dailyLossLimit),
            now,
            now + BigInt(86_400),
            capped.riskLevel,
            capped.markets.map((m) => MARKET_ADDR[m.symbol as keyof typeof MARKET_ADDR]),
            capped.markets.map((m) => BigInt(m.limit)),
          ],
        });
        await s.refetchOnchain();
        setIssueNote(`Allocated ${usd(room)} to the sitting trader and wrote policy onchain.`);
      } catch (err) {
        setIssueNote(err instanceof BaseError ? err.shortMessage : String(err));
      }
    },
  });

  const [theme, setTheme] = useState<Theme>("dark");
  useEffect(() => {
    const sync = () => setTheme(readTheme());
    sync();
    window.addEventListener(THEME_EVENT, sync);
    return () => window.removeEventListener(THEME_EVENT, sync);
  }, []);

  const curve = useMemo(() => {
    const rows = trades.data?.trades ?? [];
    let run = 0;
    return rows.map((t) => {
      run += Number(t.pnl ?? 0);
      return run;
    });
  }, [trades.data]);
  const chart = theme === "light"
    ? { line: "#5c6570", fill: "rgba(0,168,184,0.10)" }
    : { line: "#8b93a1", fill: "rgba(0,212,232,0.10)" };

  const c = credit.data;
  const analyzing = credit.isFetching && !c;
  const revert = error instanceof BaseError ? error.shortMessage : error?.message;

  return (
    <section className="kx-page">
      <CreditState />
      <header className="kx-page-head">
        <div>
          <p className="kx-kicker">Credit profile</p>
          <h1>Profile</h1>
          <p className="kx-lede">
            Score decides eligibility. Vault liquidity decides what can actually be issued. Credit
            stays on the sitting account — not USDC in your wallet.
          </p>
          {!isConnected ? <ConnectHint to="build this profile and request credit" /> : null}
        </div>
        <button
          type="button"
          className="kx-btn kx-btn-primary"
          disabled={request.isPending || isPending || !s.creditWallet}
          onClick={() => {
            setIssueNote(null);
            request.mutate();
          }}
        >
          {request.isPending || isPending
            ? operator
              ? "Issuing…"
              : "Evaluating…"
            : operator
              ? "Request & issue credit"
              : "Request credit"}
        </button>
      </header>

      {analyzing ? (
        <div className="kx-panel">
          <p className="kx-kicker">Building your credit profile</p>
          <p className="kx-hint">Wallet {compact(s.creditWallet ?? wallet)}</p>
          <ul className="kx-checks">
            <li className="is-ok"><span>✓</span><span>Trading history</span><span /></li>
            <li className="is-ok"><span>✓</span><span>Realized PnL</span><span /></li>
            <li className="is-ok"><span>✓</span><span>Drawdown · leverage · consistency</span><span /></li>
          </ul>
        </div>
      ) : null}

      <div className="kx-grid-4">
        <Metric label="Score" value={c ? String(c.score) : "—"} tone="intel" />
        <Metric label="Tier" value={c?.tier ?? "—"} />
        <Metric label="Recommended capacity" value={usd(c?.base_credit)} hint="Eligibility, not inventory" tone="intel" />
        <Metric label="Issuable now" value={usd(s.sitting ? s.issued : 0)} hint="Onchain issued · vault-capped" />
      </div>

      <div className="kx-split">
        <div className="kx-panel">
          <p className="kx-kicker">Market inventory</p>
          <table className="kx-table">
            <tbody>
              <tr>
                <td>Vault TVL</td>
                <td className="kx-num">{usd(s.tvl)}</td>
              </tr>
              <tr>
                <td>Available liquidity</td>
                <td className="kx-num">{usd(s.availableLiquidity)}</td>
              </tr>
              <tr>
                <td>Sitting allocated</td>
                <td className="kx-num">{usd(s.traderAllocated)}</td>
              </tr>
            </tbody>
          </table>
          <p className="kx-hint">
            Recommended {usd(c?.base_credit)}. Maximum currently issuable extra {usd(s.availableLiquidity)}.
            {!s.sitting
              ? ` This sitting Credit Account is bound to ${compact(DEMO_WALLET)}.`
              : operator
                ? " Operator can allocate unused liquidity to the sitting trader."
                : " Connect the operator wallet to allocate unused liquidity."}
          </p>
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
                <td>Trades</td>
                <td className="kx-num">{String(trades.data?.count ?? "—")}</td>
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
                    lineStyle: { color: chart.line, width: 1.5 },
                    areaStyle: { color: chart.fill },
                  },
                ],
              }}
            />
          ) : null}
        </div>
      </div>
      {issueNote ? <p className="kx-ok">{issueNote}</p> : null}
      {request.data && !issueNote ? (
        <p className="kx-ok">
          Profile {request.data.score} / {request.data.tier}. Recommended {usd(request.data.base_credit)} — not issued.
        </p>
      ) : null}
      {request.error ? <p className="kx-err">{String(request.error)}</p> : null}
      {revert ? <p className="kx-err">{revert}</p> : null}
    </section>
  );
}
