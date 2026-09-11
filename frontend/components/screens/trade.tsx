"use client";

import { useEffect, useMemo, useState } from "react";
import { parseUnits } from "viem";
import { BaseError } from "viem";
import { useAccount, useChainId, useWriteContract } from "wagmi";

import { ConnectHint } from "@/components/connect-hint";
import { CreditState } from "@/components/credit-state";
import { accountAbi } from "@/lib/abi";
import { reviewTrade } from "@/lib/checks";
import { DEMO_WALLET, explorerTx, MARKET_ADDR } from "@/lib/config";
import { compact, leverageLabel, usd } from "@/lib/format";
import { MONAD_TESTNET_ID } from "@/lib/monad";
import { useCreditState } from "@/lib/use-credit-state";
import { useViewWallet } from "@/lib/use-view-wallet";

export function TradeScreen() {
  const s = useCreditState();
  const { isConnected } = useViewWallet();
  const { isConnected: connected } = useAccount();
  const chainId = useChainId();
  const [market, setMarket] = useState("BTC");
  const [size, setSize] = useState("");
  const [sizeLocked, setSizeLocked] = useState(false);
  const [leverage, setLeverage] = useState("2");
  const [price, setPrice] = useState("60000");
  const [side, setSide] = useState<0 | 1>(0);
  const [phase, setPhase] = useState<"idle" | "draw" | "trade">("idle");
  const [drawTx, setDrawTx] = useState<`0x${string}` | null>(null);
  const [tradeTx, setTradeTx] = useState<`0x${string}` | null>(null);
  const { writeContractAsync, isPending, error } = useWriteContract();
  const onTestnet = chainId === MONAD_TESTNET_ID;
  const policy = s.policy;

  useEffect(() => {
    if (sizeLocked) return;
    const cap = Number(policy?.markets.BTC ?? 0);
    if (!cap) return;
    setSize(String(Math.max(1, Math.floor(cap * 0.4))));
    setSizeLocked(true);
  }, [policy, sizeLocked]);

  const sizeN = Number(size) || 0;
  const levN = Number(leverage) || 0;
  const margin = levN > 0 ? sizeN / levN : 0;
  const remaining = Math.max(s.available - margin, 0);
  const needDraw = margin > s.idle + 1e-9;
  const drawAmt = Math.max(margin - s.idle, 0);
  const checks = useMemo(
    () => reviewTrade({ policy, market, size: sizeN, leverage: levN }),
    [policy, market, sizeN, levN],
  );
  const allOk = checks.every((c) => c.ok);
  const revert = error instanceof BaseError ? error.shortMessage : error?.message;
  const marketCap = Number(policy?.markets[market] ?? 0);
  const canSend = connected && onTestnet && Boolean(s.kredxo.tradingAccount) && s.sitting;

  async function draw() {
    if (!onTestnet || !s.kredxo.tradingAccount) return;
    setPhase("draw");
    const hash = await writeContractAsync({
      chainId: MONAD_TESTNET_ID,
      address: s.kredxo.tradingAccount,
      abi: accountAbi,
      functionName: "draw",
      args: [parseUnits(drawAmt.toFixed(6), 6)],
    });
    setDrawTx(hash);
    await s.refetchOnchain();
    setPhase("idle");
  }

  async function execute() {
    if (!onTestnet || !s.kredxo.tradingAccount) return;
    setPhase("trade");
    const sizeRaw = parseUnits(size || "0", 6);
    const levWad = BigInt(Math.round(levN * 1e18));
    const priceWad = parseUnits(price, 18);
    const marketAddr = MARKET_ADDR[market as keyof typeof MARKET_ADDR];
    const hash = await writeContractAsync({
      chainId: MONAD_TESTNET_ID,
      address: s.kredxo.tradingAccount,
      abi: accountAbi,
      functionName: "executeTrade",
      args: [marketAddr, side, sizeRaw, levWad, priceWad],
    });
    setTradeTx(hash);
    await s.refetchOnchain();
    setPhase("idle");
  }

  return (
    <section className="kx-page">
      <CreditState />
      <header className="kx-page-head">
        <div>
          <p className="kx-kicker">Credit-aware execution</p>
          <h1>Execute</h1>
          <p className="kx-lede">
            Draw moves vault utilization. Execute locks idle USDC as margin. Perpl and Kuru are not
            bound on this sitting.
          </p>
          {!isConnected ? <ConnectHint to="draw credit and execute" /> : null}
        </div>
      </header>

      {isConnected && !s.sitting ? (
        <p className="kx-hint">
          Connect {compact(DEMO_WALLET)} or the operator. A random wallet cannot trade this account.
        </p>
      ) : null}

      <div className="kx-split">
        <form
          className="kx-panel kx-form"
          onSubmit={(e) => {
            e.preventDefault();
            void execute().catch(() => setPhase("idle"));
          }}
        >
          <div className="kx-field">
            Venue
            <div className="kx-venues">
              <button type="button" className="kx-venue is-on">
                <strong>Internal</strong>
                <em>Live</em>
              </button>
              <button type="button" className="kx-venue" disabled>
                <strong>Perpl</strong>
                <em>Not bound</em>
              </button>
              <button type="button" className="kx-venue" disabled>
                <strong>Kuru</strong>
                <em>Not bound</em>
              </button>
            </div>
          </div>
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
            Position size
            <input
              className="kx-input"
              value={size}
              onChange={(e) => {
                setSizeLocked(true);
                setSize(e.target.value);
              }}
            />
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
          {needDraw ? (
            <button
              type="button"
              className="kx-btn kx-btn-primary"
              disabled={!canSend || isPending || drawAmt <= 0}
              onClick={() => void draw().catch(() => setPhase("idle"))}
            >
              {phase === "draw" ? "Drawing…" : `Draw ${usd(drawAmt)} to account`}
            </button>
          ) : null}
          <button
            type="submit"
            className="kx-btn kx-btn-primary"
            disabled={!canSend || isPending || needDraw}
          >
            {phase === "trade" ? "Sending…" : "Execute on Monad"}
          </button>
          {needDraw ? (
            <p className="kx-hint">
              Idle USDC {usd(s.idle)} is below required margin {usd(margin)}. Draw first — that is
              what utilizes the vault.
            </p>
          ) : null}
          {!onTestnet ? (
            <p className="kx-hint">Switch to Monad Testnet. Kredxo credit lives on 10143.</p>
          ) : !s.kredxo.tradingAccount ? (
            <p className="kx-hint">Trading account is not available.</p>
          ) : isConnected && !s.sitting ? (
            <p className="kx-hint">This wallet is not the sitting trader or operator.</p>
          ) : isConnected ? (
            <p className="kx-hint">Perpl and Kuru are not live on this sitting.</p>
          ) : null}
          {revert ? <p className="kx-err">Rejected: {revert}</p> : null}
        </form>

        <div className="kx-execute-side">
          <div className="kx-panel">
            <p className="kx-kicker">Credit impact</p>
            <table className="kx-table">
              <tbody>
                <tr>
                  <td>Issued</td>
                  <td className="kx-num">{usd(s.issued)}</td>
                </tr>
                <tr>
                  <td>Drawn</td>
                  <td className="kx-num">{usd(s.used)}</td>
                </tr>
                <tr>
                  <td>Idle on account</td>
                  <td className="kx-num">{usd(s.idle)}</td>
                </tr>
                <tr>
                  <td>Required margin</td>
                  <td className="kx-num">{usd(margin)}</td>
                </tr>
                <tr>
                  <td>Unused capacity</td>
                  <td className="kx-num">{usd(remaining)}</td>
                </tr>
                <tr>
                  <td>{market} cap</td>
                  <td className="kx-num">{usd(marketCap)}</td>
                </tr>
                <tr>
                  <td>Max leverage</td>
                  <td className="kx-num">{leverageLabel(policy?.maxLeverage)}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div className="kx-panel">
            <p className="kx-kicker">Policy</p>
            <ul className="kx-checks">
              {checks.map((c) => (
                <li key={c.id} className={c.ok ? "is-ok" : "is-bad"}>
                  <span>{c.ok ? "✓" : "✕"}</span>
                  <span>{c.label}</span>
                  <span className="kx-muted">{c.detail}</span>
                </li>
              ))}
            </ul>
            <p className="kx-hint">
              {allOk
                ? "Preview would pass. The account is still the authority."
                : "Preview would fail. Submitting still hits the live policy."}
            </p>
          </div>
          {tradeTx || drawTx ? (
            <div className="kx-receipt">
              <p className="kx-kicker">Onchain</p>
              {drawTx ? (
                <p className="kx-ok">
                  Credit drawn.{" "}
                  <a className="kx-footer-link" href={explorerTx(drawTx)} target="_blank" rel="noreferrer">
                    Draw tx
                  </a>
                </p>
              ) : null}
              {tradeTx ? (
                <p className="kx-ok">
                  {market} {side === 0 ? "LONG" : "SHORT"} {usd(sizeN)} executed. Drawn {usd(s.used)} ·
                  idle {usd(s.idle)}.{" "}
                  <a className="kx-footer-link" href={explorerTx(tradeTx)} target="_blank" rel="noreferrer">
                    Trade tx
                  </a>
                </p>
              ) : null}
            </div>
          ) : null}
        </div>
      </div>
    </section>
  );
}
