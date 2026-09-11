"use client";

import { useState } from "react";
import { parseUnits } from "viem";
import { BaseError } from "viem";
import {
  useAccount,
  useChainId,
  usePublicClient,
  useReadContract,
  useWriteContract,
} from "wagmi";

import { ConnectHint } from "@/components/connect-hint";
import { isOperator } from "@/lib/actors";
import { usdcAbi, vaultAbi } from "@/lib/abi";
import { DEMO_WALLET, OPERATOR_ADDRESS, explorerTx } from "@/lib/config";
import { compact, pct, usd, units6 } from "@/lib/format";
import { MONAD_TESTNET_ID } from "@/lib/monad";
import { kredxoOn } from "@/lib/networks";
import { useProtocolBook } from "@/lib/use-protocol-book";

type Receipt = {
  amount: number;
  beforeTvl: number;
  afterTvl: number;
  sharePct: number;
  tx: `0x${string}`;
};

export function MarketScreen() {
  const { address } = useAccount();
  const book = useProtocolBook();
  const { tvl, allocated, utilized, available, supplyShares, vaultOn, utilPct } = book;
  const reservedIdle = Math.max(allocated - utilized, 0);
  const allocPct = tvl > 0 ? allocated / tvl : 0;
  const availPct = tvl > 0 ? available / tvl : 0;

  return (
    <section className="kx-page">
      <header className="kx-page-head">
        <div>
          <p className="kx-kicker">Liquidity</p>
          <h1>BTC / ETH trading credit</h1>
          <p className="kx-lede">
            One USDC credit market. You fund capacity. Traders receive a constrained Credit Account,
            not USDC in their wallet.
          </p>
        </div>
      </header>

      <div className="kx-market-hero">
        <div className="kx-panel">
          <p className="kx-kicker">Adaptive credit market</p>
          <p className="kx-account-issued">{usd(tvl)}</p>
          <p className="kx-hint">
            {vaultOn ? "Total supplied · live testnet" : "Vault not on this network"}
          </p>
          <table className="kx-table">
            <tbody>
              <tr>
                <td>Allocated</td>
                <td className="kx-num">{usd(allocated)}</td>
              </tr>
              <tr>
                <td>Utilized</td>
                <td className="kx-num">{usd(utilized)}</td>
              </tr>
              <tr>
                <td>Available</td>
                <td className="kx-num">{usd(available)}</td>
              </tr>
            </tbody>
          </table>
          <p className="kx-kicker" style={{ marginTop: "1rem" }}>
            Credit demand
          </p>
          <div className="kx-demand-track" aria-hidden>
            <span className="kx-demand-seg is-util" style={{ width: `${Math.min(utilPct, 1) * 100}%` }} />
            <span
              className="kx-demand-seg is-alloc"
              style={{ width: `${Math.min(Math.max(allocPct - utilPct, 0), 1) * 100}%` }}
            />
            <span className="kx-demand-seg is-idle" style={{ width: `${Math.min(availPct, 1) * 100}%` }} />
          </div>
          <p className="kx-hint">
            Drawn {usd(utilized)} · reserved unused {usd(reservedIdle)} · idle {usd(available)}.
            Yield accrues on utilized credit. Sitting trader {compact(DEMO_WALLET)}.
          </p>
        </div>
        <LpDesk
          connected={Boolean(address)}
          address={address}
          vaultOn={vaultOn}
          tvl={tvl}
          available={available}
          supplyShares={supplyShares}
          onSettled={() => void book.refetch()}
        />
      </div>
    </section>
  );
}

function LpDesk({
  connected,
  address,
  vaultOn,
  tvl,
  available,
  supplyShares,
  onSettled,
}: {
  connected: boolean;
  address?: `0x${string}`;
  vaultOn: boolean;
  tvl: number;
  available: number;
  supplyShares: bigint | undefined;
  onSettled: () => void;
}) {
  const [amount, setAmount] = useState("10");
  const [withdrawAmt, setWithdrawAmt] = useState("");
  const [phase, setPhase] = useState<"idle" | "approve" | "deposit">("idle");
  const [receipt, setReceipt] = useState<Receipt | null>(null);
  const chainId = useChainId();
  const kredxo = kredxoOn(chainId);
  const publicClient = usePublicClient({ chainId: MONAD_TESTNET_ID });
  const { writeContractAsync, isPending, error } = useWriteContract();
  const onTestnet = chainId === MONAD_TESTNET_ID;
  const ready = Boolean(kredxo.vault && kredxo.usdc && connected && onTestnet);

  const shares = useReadContract({
    address: kredxo.vault || undefined,
    abi: vaultAbi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(kredxo.vault && address) },
  });
  const assets = useReadContract({
    address: kredxo.vault || undefined,
    abi: vaultAbi,
    functionName: "convertToAssets",
    args: shares.data !== undefined ? [shares.data] : undefined,
    query: { enabled: Boolean(kredxo.vault && shares.data !== undefined) },
  });
  const seedShares = useReadContract({
    address: kredxo.vault || undefined,
    abi: vaultAbi,
    functionName: "balanceOf",
    args: [OPERATOR_ADDRESS],
    query: { enabled: Boolean(kredxo.vault) },
  });
  const seedAssets = useReadContract({
    address: kredxo.vault || undefined,
    abi: vaultAbi,
    functionName: "convertToAssets",
    args: seedShares.data !== undefined ? [seedShares.data] : undefined,
    query: { enabled: Boolean(kredxo.vault && seedShares.data !== undefined) },
  });
  const walletUsdc = useReadContract({
    address: kredxo.usdc || undefined,
    abi: usdcAbi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: Boolean(kredxo.usdc && address) },
  });

  const lpAssets = units6(assets.data) ?? 0;
  const protocolAssets = units6(seedAssets.data) ?? 0;
  const userIsSeed = isOperator(address);
  const sharePct =
    supplyShares && supplyShares > BigInt(0) && shares.data !== undefined
      ? Number(shares.data) / Number(supplyShares)
      : 0;
  const maxWithdraw = Math.max(0, Math.min(lpAssets, available));
  const revert = error instanceof BaseError ? error.shortMessage : error?.message;
  const canWithdraw = ready && maxWithdraw > 0 && Number(withdrawAmt || "0") > 0;
  const walletBal = units6(walletUsdc.data) ?? 0;
  const parsedAmt = Number(amount || "0");

  async function refreshPosition() {
    onSettled();
    await Promise.all([shares.refetch(), assets.refetch(), seedShares.refetch(), seedAssets.refetch()]);
  }

  async function supply() {
    const vault = kredxo.vault;
    const usdc = kredxo.usdc;
    if (!vault || !usdc || !onTestnet) return;
    const parsed = parseUnits(amount || "0", 6);
    const beforeTvl = tvl;
    setPhase("approve");
    await writeContractAsync({
      chainId: MONAD_TESTNET_ID,
      address: usdc,
      abi: usdcAbi,
      functionName: "approve",
      args: [vault, parsed],
    });
    setPhase("deposit");
    const tx = await writeContractAsync({
      chainId: MONAD_TESTNET_ID,
      address: vault,
      abi: vaultAbi,
      functionName: "deposit",
      args: [parsed],
    });
    await refreshPosition();
    setReceipt({
      amount: parsedAmt,
      beforeTvl,
      afterTvl: beforeTvl + parsedAmt,
      sharePct: tvl + parsedAmt > 0 ? parsedAmt / (tvl + parsedAmt) : 0,
      tx,
    });
    setPhase("idle");
  }

  async function withdraw() {
    const vault = kredxo.vault;
    if (!vault || !onTestnet || !publicClient) return;
    const want = parseUnits(withdrawAmt || "0", 6);
    const shareAmt = await publicClient.readContract({
      address: vault,
      abi: vaultAbi,
      functionName: "convertToShares",
      args: [want],
    });
    if (shareAmt === BigInt(0)) return;
    await writeContractAsync({
      chainId: MONAD_TESTNET_ID,
      address: vault,
      abi: vaultAbi,
      functionName: "withdraw",
      args: [shareAmt],
    });
    setReceipt(null);
    await refreshPosition();
  }

  return (
    <div className="kx-panel">
      <p className="kx-kicker">Your position</p>
      {connected && vaultOn ? (
        <>
          <p className="kx-account-issued">{usd(lpAssets)}</p>
          <p className="kx-hint">
            Your vault USDC
            {supplyShares && supplyShares > BigInt(0) && shares.data !== undefined
              ? ` · ${pct(sharePct, 1)} of supply`
              : ""}
          </p>
        </>
      ) : (
        <p className="kx-hint">{connected ? "Vault not on this network." : "No LP position yet."}</p>
      )}

      <table className="kx-table">
        <tbody>
          <tr>
            <td>Protocol liquidity</td>
            <td className="kx-num">{usd(userIsSeed ? lpAssets : protocolAssets)}</td>
          </tr>
          <tr>
            <td>Your supplied</td>
            <td className="kx-num">{usd(userIsSeed ? lpAssets : lpAssets)}</td>
          </tr>
          <tr>
            <td>Wallet USDC</td>
            <td className="kx-num">{usd(walletBal)}</td>
          </tr>
        </tbody>
      </table>

      {receipt ? (
        <div className="kx-receipt">
          <p className="kx-kicker">Liquidity supplied</p>
          <p className="kx-ok">USDC approved · capital deposited · LP position updated</p>
          <table className="kx-table">
            <tbody>
              <tr>
                <td>You supplied</td>
                <td className="kx-num">{usd(receipt.amount)}</td>
              </tr>
              <tr>
                <td>TVL</td>
                <td className="kx-num">
                  {usd(receipt.beforeTvl)} → {usd(receipt.afterTvl)}
                </td>
              </tr>
            </tbody>
          </table>
          <p className="kx-hint">
            <a className="kx-footer-link" href={explorerTx(receipt.tx)} target="_blank" rel="noreferrer">
              View deposit
            </a>
          </p>
        </div>
      ) : null}

      <label className="kx-field">
        Supply amount
        <input
          className="kx-input"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          inputMode="decimal"
        />
      </label>
      <p className="kx-hint">
        You supply {usd(parsedAmt)}
        {tvl + parsedAmt > 0 ? ` · ~${pct(parsedAmt / (tvl + parsedAmt), 1)} of market after` : ""}
      </p>
      <button
        type="button"
        className="kx-btn kx-btn-primary"
        disabled={!ready || isPending || parsedAmt <= 0}
        onClick={() => void supply().catch(() => setPhase("idle"))}
      >
        {phase === "approve"
          ? "Approve USDC…"
          : phase === "deposit"
            ? "Deposit…"
            : "Approve & supply USDC"}
      </button>

      <label className="kx-field">
        Withdraw amount
        <input
          className="kx-input"
          value={withdrawAmt}
          onChange={(e) => setWithdrawAmt(e.target.value)}
          inputMode="decimal"
          placeholder={maxWithdraw > 0 ? String(maxWithdraw) : "0"}
        />
      </label>
      <button
        type="button"
        className="kx-btn"
        disabled={!canWithdraw || isPending}
        onClick={() => void withdraw()}
      >
        Withdraw USDC
      </button>
      <p className="kx-hint">
        Withdrawable {usd(maxWithdraw)}. Allocated credit is reserved and cannot be pulled.
      </p>

      {!onTestnet ? (
        <p className="kx-hint">Switch to Monad Testnet to use the live vault.</p>
      ) : !kredxo.vault || !kredxo.usdc ? (
        <p className="kx-hint">Vault is not available on this network.</p>
      ) : !connected ? (
        <ConnectHint to="supply or withdraw" />
      ) : null}
      {revert ? <p className="kx-err">{revert}</p> : null}
    </div>
  );
}
