"use client";

import { useState } from "react";
import { BaseError, parseUnits } from "viem";
import { useChainId, useWriteContract } from "wagmi";

import { ConnectHint } from "@/components/connect-hint";
import { CreditState } from "@/components/credit-state";
import { RiskBadge } from "@/components/risk-badge";
import { accountAbi } from "@/lib/abi";
import { DEMO_WALLET, explorerTx } from "@/lib/config";
import { compact, leverageLabel, usd } from "@/lib/format";
import { MONAD_TESTNET_ID } from "@/lib/monad";
import { useCreditState } from "@/lib/use-credit-state";
import { useOnchainPositions } from "@/lib/use-onchain-positions";
import { useViewWallet } from "@/lib/use-view-wallet";

export function AccountScreen() {
  const { wallet, isConnected } = useViewWallet();
  const s = useCreditState();
  const chainId = useChainId();
  const p = s.policy;
  const positions = useOnchainPositions(s.sitting);
  const { writeContractAsync, isPending, error, data } = useWriteContract();
  const [price, setPrice] = useState("60000");
  const onTestnet = chainId === MONAD_TESTNET_ID;
  const revert = error instanceof BaseError ? error.shortMessage : error?.message;

  async function close(id: number) {
    if (!s.kredxo.tradingAccount || !onTestnet) return;
    await writeContractAsync({
      chainId: MONAD_TESTNET_ID,
      address: s.kredxo.tradingAccount,
      abi: accountAbi,
      functionName: "closePosition",
      args: [BigInt(id), parseUnits(price, 18)],
    });
    await positions.refetch();
    await s.refetchOnchain();
  }

  return (
    <section className="kx-page">
      <CreditState />
      <header className="kx-page-head">
        <div>
          <p className="kx-kicker">Credit account</p>
          <h1>Account</h1>
          <p className="kx-lede">
            {wallet
              ? `Wallet ${compact(wallet)} owns the relationship. The Credit Account is where controlled trading happens. Withdrawals are disabled.`
              : "The Credit Account is where controlled trading happens. Withdrawals are disabled."}
          </p>
        </div>
      </header>

      {!isConnected ? (
        <ConnectHint to="use this Credit Account" />
      ) : !s.sitting ? (
        <p className="kx-hint">
          This sitting account is owned by {compact(DEMO_WALLET)}. Connect that trader or the
          operator to draw, trade, or close.
        </p>
      ) : null}

      <div className="kx-account-hero">
        <div className="kx-panel kx-account-capacity">
          <p className="kx-kicker">Capacity</p>
          <p className="kx-account-issued">{usd(s.issued)}</p>
          <p className="kx-hint">
            Issued onchain{s.issuedOnchain === null ? " · not this wallet’s account" : ""}
          </p>
          <table className="kx-table">
            <tbody>
              <tr>
                <td>Owner</td>
                <td className="kx-num kx-mono">{compact(DEMO_WALLET)}</td>
              </tr>
              <tr>
                <td>Account</td>
                <td className="kx-num kx-mono">
                  {s.kredxo.tradingAccount ? compact(s.kredxo.tradingAccount) : "—"}
                </td>
              </tr>
              <tr>
                <td>Recommended</td>
                <td className="kx-num">{usd(s.recommended)}</td>
              </tr>
              <tr>
                <td>Drawn / used</td>
                <td className="kx-num">{usd(s.used)}</td>
              </tr>
              <tr>
                <td>Idle USDC on account</td>
                <td className="kx-num">{usd(s.idle)}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div className="kx-panel kx-account-risk">
          <p className="kx-kicker">Risk state</p>
          <RiskBadge state={s.riskLevel} />
          <p className="kx-hint">
            Trader × market{" "}
            {s.traderMult !== null && s.marketMult !== null
              ? `${s.traderMult.toFixed(3)} × ${s.marketMult.toFixed(3)}`
              : "—"}
          </p>
        </div>
      </div>

      <div className="kx-split">
        <div className="kx-panel">
          <p className="kx-kicker">Active policy</p>
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
          <p className="kx-hint">Caps are vault-capped to issued credit on this sitting.</p>
        </div>
        <div className="kx-panel">
          <p className="kx-kicker">Open positions</p>
          {positions.open.length ? (
            <table className="kx-table">
              <tbody>
                {positions.open.map((pos) => (
                  <tr key={pos.id}>
                    <td>
                      {pos.symbol} {pos.side === 0 ? "LONG" : "SHORT"}
                    </td>
                    <td className="kx-num">{usd(pos.size)}</td>
                    <td>
                      <button
                        type="button"
                        className="kx-btn"
                        disabled={!s.sitting || !onTestnet || isPending}
                        onClick={() => void close(pos.id)}
                      >
                        Close
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <p className="kx-hint">No open positions on the sitting account.</p>
          )}
          <label className="kx-field">
            Close price
            <input
              className="kx-input"
              value={price}
              onChange={(e) => setPrice(e.target.value)}
              inputMode="decimal"
            />
          </label>
          {data ? (
            <p className="kx-ok">
              Closed.{" "}
              <a className="kx-footer-link" href={explorerTx(data)} target="_blank" rel="noreferrer">
                View on MonadVision
              </a>
            </p>
          ) : null}
          {revert ? <p className="kx-err">{revert}</p> : null}
        </div>
      </div>
    </section>
  );
}
