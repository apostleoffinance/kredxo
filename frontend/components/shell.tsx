"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useBlockNumber } from "wagmi";

import { ConnectButton } from "@/components/connect";
import { api } from "@/lib/api";
import { compact } from "@/lib/format";
import { useViewWallet } from "@/lib/use-view-wallet";

const NAV = [
  { href: "/market", label: "Market" },
  { href: "/profile", label: "Profile" },
  { href: "/account", label: "Account" },
  { href: "/trade", label: "Trade" },
  { href: "/risk", label: "Risk" },
];

export function Shell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { wallet, isDemo } = useViewWallet();
  const { data: block } = useBlockNumber({ watch: true });
  const health = useQuery({ queryKey: ["health"], queryFn: api.health, refetchInterval: 15_000 });

  return (
    <div className="kx-root">
      <header className="kx-top">
        <div className="kx-brand">
          <span className="kx-mark">KREDXO</span>
          <span className="kx-sub">Adaptive credit</span>
        </div>
        <nav className="kx-nav">
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={pathname === item.href ? "kx-nav-link is-active" : "kx-nav-link"}
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="kx-top-right">
          <span className="kx-mono kx-muted">
            {health.data?.monad.rpc_ok ? "Monad · live" : "Monad"}
            {block !== undefined ? ` · #${block.toString()}` : ""}
          </span>
          <ConnectButton />
        </div>
      </header>
      <div className="kx-strip">
        <span>Python decides. Solidity enforces.</span>
        <span>
          Viewing {compact(wallet)}
          {isDemo ? " · demo history" : ""}
        </span>
        <span>Phase {health.data?.phase ?? "—"}</span>
      </div>
      <main className="kx-main">{children}</main>
    </div>
  );
}
