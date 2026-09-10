"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { parseUnits } from "viem";
import { useAccount, useReadContracts, useWriteContract } from "wagmi";

import { Metric } from "@/components/metric";
import { usdcAbi, vaultAbi } from "@/lib/abi";
import { api } from "@/lib/api";
import { TRADING_ACCOUNT_ADDRESS, USDC_ADDRESS, VAULT_ADDRESS } from "@/lib/config";
import { pct, usd } from "@/lib/format";

export function MarketScreen() {
  const markets = useQuery({ queryKey: ["markets"], queryFn: api.markets });
  const { address } = useAccount();
  const vaultOn = Boolean(VAULT_ADDRESS);
  const onchain = useReadContracts({
    query: { enabled: vaultOn && Boolean(VAULT_ADDRESS) },
    contracts: VAULT_ADDRESS
      ? [
          { address: VAULT_ADDRESS, abi: vaultAbi, functionName: "totalAssets" },
          { address: VAULT_ADDRESS, abi: vaultAbi, functionName: "allocatedCredit" },
          { address: VAULT_ADDRESS, abi: vaultAbi, functionName: "utilizedCredit" },
        ]
      : [],
  });

  const tvlOnchain = onchain.data?.[0]?.result;
  const allocatedOnchain = onchain.data?.[1]?.result;
  const utilizedOnchain = onchain.data?.[2]?.result;
  const tvl =
    tvlOnchain !== undefined ? Number(tvlOnchain) / 1e6 : Number(markets.data?.tvl ?? 0);
  const allocated =
    allocatedOnchain !== undefined
      ? Number(allocatedOnchain) / 1e6
      : Number(markets.data?.allocated ?? 0);
  const utilized =
    utilizedOnchain !== undefined
      ? Number(utilizedOnchain) / 1e6
      : Number(markets.data?.utilized ?? 0);
  const utilization = tvl > 0 ? utilized / tvl : Number(markets.data?.utilization ?? 0);

  return (
    <section className="kx-page">
      <header className="kx-page-head">
        <div>
          <p className="kx-kicker">USDC trading credit market</p>
          <h1>Market</h1>
        </div>
        <p className="kx-lede">
          One credit market. LPs fund capacity; traders receive a credit account, not
          unrestricted USDC.
        </p>
      </header>

      <div className="kx-grid-4">
        <Metric label="TVL" value={usd(tvl)} hint={vaultOn ? "Vault totalAssets" : "Vault not deployed"} />
        <Metric label="Allocated" value={usd(allocated)} hint="Reserved capacity" />
        <Metric label="Utilized" value={usd(utilized)} hint={`${pct(utilization)} of TVL`} />
        <Metric
          label="Borrow APR"
          value={pct(markets.data?.current_apr, 1)}
          hint={`Base ${pct(markets.data?.base_apr, 0)} + risk + utilization`}
        />
      </div>

      <div className="kx-split">
        <div className="kx-panel">
          <p className="kx-kicker">APR band</p>
          <table className="kx-table">
            <tbody>
              <tr>
                <td>LOW · idle</td>
                <td className="kx-num">{pct(markets.data?.apr.low)}</td>
              </tr>
              <tr>
                <td>NORMAL · current util</td>
                <td className="kx-num">{pct(markets.data?.apr.normal)}</td>
              </tr>
              <tr>
                <td>HIGH · 50% util</td>
                <td className="kx-num">{pct(markets.data?.apr.high)}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <SupplyPanel connected={Boolean(address)} />
      </div>
    </section>
  );
}

function SupplyPanel({ connected }: { connected: boolean }) {
  const [amount, setAmount] = useState("1000");
  const { writeContractAsync, isPending, error, data } = useWriteContract();
  const ready = Boolean(VAULT_ADDRESS && USDC_ADDRESS && connected);

  async function supply() {
    if (!VAULT_ADDRESS || !USDC_ADDRESS) return;
    const assets = parseUnits(amount || "0", 6);
    await writeContractAsync({
      address: USDC_ADDRESS,
      abi: usdcAbi,
      functionName: "approve",
      args: [VAULT_ADDRESS, assets],
    });
    await writeContractAsync({
      address: VAULT_ADDRESS,
      abi: vaultAbi,
      functionName: "deposit",
      args: [assets],
    });
  }

  return (
    <div className="kx-panel">
      <p className="kx-kicker">Supply USDC</p>
      <p className="kx-hint">
        Deposits mint kUSDC against vault NAV. Reserved credit is not withdrawable.
      </p>
      <label className="kx-field">
        Amount
        <input
          className="kx-input"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          inputMode="decimal"
        />
      </label>
      <button
        type="button"
        className="kx-btn kx-btn-primary"
        disabled={!ready || isPending}
        onClick={() => void supply()}
      >
        {isPending ? "Submitting…" : "Supply USDC"}
      </button>
      {!VAULT_ADDRESS || !USDC_ADDRESS ? (
        <p className="kx-hint">
          Vault / USDC addresses are unset. Supply stays disabled until deploy.
          {TRADING_ACCOUNT_ADDRESS ? "" : ""}
        </p>
      ) : !connected ? (
        <p className="kx-hint">Connect a wallet to supply.</p>
      ) : null}
      {data ? <p className="kx-ok">Submitted {data}</p> : null}
      {error ? <p className="kx-err">{error.message}</p> : null}
    </div>
  );
}
