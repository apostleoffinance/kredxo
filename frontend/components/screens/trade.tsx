"use client";

import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { parseUnits } from "viem";
import { BaseError } from "viem";
import { useAccount, useWriteContract } from "wagmi";

import { accountAbi } from "@/lib/abi";
import { api } from "@/lib/api";
import { reviewTrade } from "@/lib/checks";
import { MARKET_ADDR, TRADING_ACCOUNT_ADDRESS } from "@/lib/config";
import { leverageLabel, usd } from "@/lib/format";
import { useViewWallet } from "@/lib/use-view-wallet";

export function TradeScreen() {
  const { wallet } = useViewWallet();
  const { isConnected } = useAccount();
  const policyQ = useQuery({ queryKey: ["policy", wallet], queryFn: () => api.policy(wallet) });
  const [market, setMarket] = useState("BTC");
  const [size, setSize] = useState("20000");
  const [leverage, setLeverage] = useState("2");
  const [price, setPrice] = useState("60000");
  const [side, setSide] = useState<0 | 1>(0);
  const { writeContractAsync, isPending, error, data } = useWriteContract();

  const policy = policyQ.data?.policy ?? null;
  const sizeN = Number(size) || 0;
  const levN = Number(leverage) || 0;
  const checks = useMemo(
    () => reviewTrade({ policy, market, size: sizeN, leverage: levN }),
    [policy, market, sizeN, levN],
  );
  const allOk = checks.every((c) => c.ok);
  const revert = error instanceof BaseError ? error.shortMessage : error?.message;

  async function execute() {
    if (!TRADING_ACCOUNT_ADDRESS) return;
    await writeContractAsync({
      address: TRADING_ACCOUNT_ADDRESS,
      abi: accountAbi,
      functionName: "executeTrade",
      args: [
        MARKET_ADDR[market as keyof typeof MARKET_ADDR],
        side,
        parseUnits(size, 6),
        BigInt(Math.round(levN * 1e18)),
        parseUnits(price, 18),
      ],
    });
  }

  return (
    <section className="kx-page">
      <header className="kx-page-head">
        <div>
          <p className="kx-kicker">Execution</p>
          <h1>Trade</h1>
        </div>
        <p className="kx-lede">
          Review is from the live policy. Rejection is onchain. The UI does not block a revert.
        </p>
      </header>

      <div className="kx-split">
        <form
          className="kx-panel kx-form"
          onSubmit={(e) => {
            e.preventDefault();
            void execute();
          }}
        >
          <label className="kx-field">
            Market
            <select className="kx-input" value={market} onChange={(e) => setMarket(e.target.value)}>
              {Object.keys(policy?.markets ?? { BTC: 0, ETH: 0 }).map((m) => (
                <option key={m}>{m}</option>
              ))}
            </select>
          </label>
          <label className="kx-field">
            Side
            <select
              className="kx-input"
              value={side}
              onChange={(e) => setSide(Number(e.target.value) as 0 | 1)}
            >
              <option value={0}>Long</option>
              <option value={1}>Short</option>
            </select>
          </label>
          <label className="kx-field">
            Size (USDC notional)
            <input className="kx-input" value={size} onChange={(e) => setSize(e.target.value)} />
          </label>
          <label className="kx-field">
            Leverage
            <input
              className="kx-input"
              value={leverage}
              onChange={(e) => setLeverage(e.target.value)}
            />
          </label>
          <label className="kx-field">
            Price
            <input className="kx-input" value={price} onChange={(e) => setPrice(e.target.value)} />
          </label>
          <p className="kx-hint">
            Policy {policy?.riskLevel ?? "—"} · BTC {usd(policy?.markets.BTC)} · max{" "}
            {leverageLabel(policy?.maxLeverage)}
          </p>
          <button
            type="submit"
            className="kx-btn kx-btn-primary"
            disabled={!TRADING_ACCOUNT_ADDRESS || !isConnected || isPending}
          >
            {isPending ? "Sending…" : "Execute onchain"}
          </button>
          {!TRADING_ACCOUNT_ADDRESS ? (
            <p className="kx-hint">Trading account not deployed. Checks still use live policy.</p>
          ) : !isConnected ? (
            <p className="kx-hint">Connect the trader key to send executeTrade.</p>
          ) : null}
          {data ? <p className="kx-ok">tx {data}</p> : null}
          {revert ? (
            <p className="kx-err">
              Onchain: {revert}
            </p>
          ) : null}
        </form>

        <div className="kx-panel">
          <p className="kx-kicker">Contract checks</p>
          <ul className="kx-checks">
            {checks.map((c) => (
              <li key={c.id} className={c.ok ? "is-ok" : "is-bad"}>
                <span>{c.ok ? "PASS" : "FAIL"}</span>
                <span>{c.label}</span>
                <span className="kx-muted">{c.detail}</span>
              </li>
            ))}
          </ul>
          <p className="kx-hint">
            {allOk
              ? "Preview would pass. The contract is still the authority."
              : "Preview would fail. Submitting still hits the contract if deployed."}
          </p>
        </div>
      </div>
    </section>
  );
}
