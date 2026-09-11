"use client";

import { useRouter } from "next/navigation";
import { useRef, useState } from "react";

import { LandingViz } from "@/components/landing-viz";
import { persistRole, type Role } from "@/lib/role";

const FADE_MS = 400;

export function SplashScreen() {
  const router = useRouter();
  const [leaving, setLeaving] = useState(false);
  const started = useRef(false);

  function go(href: string, role: Role) {
    if (started.current) return;
    started.current = true;
    persistRole(role);
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduce) {
      router.push(href);
      return;
    }
    setLeaving(true);
    window.setTimeout(() => router.push(href), FADE_MS);
  }

  return (
    <div className={leaving ? "kx-land is-leave" : "kx-land"}>
      <div className="kx-land-main">
        <div className="kx-land-copy">
          <p className="kx-land-eye">KREDXO · MONAD NATIVE</p>
          <h1 className="kx-land-title">
            Adaptive credit
            <br />
            for onchain markets.
          </h1>
          <p className="kx-land-lede">
            Kredxo turns verified trading behavior and real-time market risk into programmable
            trading credit.
          </p>
          <div className="kx-land-doors">
            <div className="kx-land-door">
              <p className="kx-land-door-kicker">Capital providers</p>
              <p className="kx-land-door-line">Earn from adaptive credit</p>
              <button
                type="button"
                className="kx-land-enter"
                onClick={() => go("/market?role=lp", "lp")}
              >
                PROVIDE LIQUIDITY
              </button>
            </div>
            <div className="kx-land-door">
              <p className="kx-land-door-kicker">Traders</p>
              <p className="kx-land-door-line">Access programmable credit</p>
              <button
                type="button"
                className="kx-land-outline"
                onClick={() => go("/profile?role=trader", "trader")}
              >
                GET CREDIT
              </button>
            </div>
          </div>
          <button
            type="button"
            className="kx-land-secondary"
            onClick={() => go("/demo?role=trader", "trader")}
          >
            View sitting
          </button>
        </div>
        <LandingViz />
      </div>
      <div className="kx-land-tele">
        <span>
          MONAD
          <strong>TESTNET · 10143</strong>
        </span>
        <span>
          ADAPTIVE CREDIT
          <strong>ACTIVE</strong>
        </span>
        <span>
          POLICY
          <strong>ACTIVE</strong>
        </span>
        <span>
          INTERNAL BOOK
          <strong>LIVE</strong>
        </span>
      </div>
    </div>
  );
}
