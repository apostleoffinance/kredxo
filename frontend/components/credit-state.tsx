"use client";

import { RiskBadge } from "@/components/risk-badge";
import { compact, leverageLabel, usd } from "@/lib/format";
import { useCreditState } from "@/lib/use-credit-state";

export function CreditState() {
  const s = useCreditState();
  if (!s.isConnected) return null;
  const btc = s.policy?.markets.BTC;
  const lev = s.policy?.maxLeverage;

  return (
    <aside className="kx-credit-rail" aria-label="Credit state">
      <div className="kx-credit-rail-head">
        <RiskBadge state={s.riskLevel} />
        <p className="kx-credit-rail-kicker">
          {s.sitting
            ? "Credit state · sitting account"
            : `Wallet ${s.wallet ? compact(s.wallet) : ""} · no sitting account`}
        </p>
      </div>
      <dl className="kx-credit-rail-row">
        <div>
          <dt>Issued</dt>
          <dd>{usd(s.issued)}</dd>
        </div>
        <div>
          <dt>Used</dt>
          <dd>{usd(s.used)}</dd>
        </div>
        <div>
          <dt>Idle USDC</dt>
          <dd>{usd(s.idle)}</dd>
        </div>
        <div>
          <dt>BTC cap</dt>
          <dd>{usd(btc)}</dd>
        </div>
        <div>
          <dt>Leverage</dt>
          <dd>{leverageLabel(lev)}</dd>
        </div>
      </dl>
      <p className="kx-credit-rail-note">
        Score {s.score ?? "—"} · recommended {usd(s.recommended)} · vault {usd(s.tvl)} ·
        available liquidity {usd(s.availableLiquidity)}
      </p>
    </aside>
  );
}
