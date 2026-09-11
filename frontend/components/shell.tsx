"use client";

import Link from "next/link";
import { Suspense } from "react";
import { usePathname } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useAccount, useBlockNumber, useChainId } from "wagmi";

import { BrandMark } from "@/components/brand-mark";
import { ConnectButton } from "@/components/connect";
import { NetworkSwitch } from "@/components/network-switch";
import { RoleToggle } from "@/components/role-toggle";
import { ThemeToggle } from "@/components/theme-toggle";
import { api } from "@/lib/api";
import { compact, pct, usd } from "@/lib/format";
import { MONAD_MAINNET_ID } from "@/lib/monad";
import { navFor, withRole, type Role } from "@/lib/role";
import { useProtocolBook } from "@/lib/use-protocol-book";
import { useRole } from "@/lib/use-role";

export function Shell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  if (pathname === "/") {
    return <>{children}</>;
  }

  return (
    <Suspense fallback={<AppChrome pathname={pathname} role="trader">{children}</AppChrome>}>
      <RoleShell pathname={pathname}>{children}</RoleShell>
    </Suspense>
  );
}

function RoleShell({ pathname, children }: { pathname: string; children: React.ReactNode }) {
  const { role, setRole } = useRole();
  return (
    <AppChrome pathname={pathname} role={role} setRole={setRole}>
      {children}
    </AppChrome>
  );
}

function AppChrome({
  pathname,
  role,
  setRole,
  children,
}: {
  pathname: string;
  role: Role;
  setRole?: (next: Role) => void;
  children: React.ReactNode;
}) {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { data: block } = useBlockNumber({ watch: true });
  const health = useQuery({ queryKey: ["health"], queryFn: api.health, refetchInterval: 15_000 });
  const book = useProtocolBook();
  const onMainnet = chainId === MONAD_MAINNET_ID;
  const nav = navFor(role);

  return (
    <div className="kx-root">
      <header className="kx-top">
        <Link href="/" className="kx-brand">
          <span className="kx-brand-row">
            <BrandMark size={18} className="kx-brand-mark" />
            <span className="kx-mark">KREDXO</span>
          </span>
        </Link>
        {setRole ? <RoleToggle role={role} setRole={setRole} /> : (
          <span className="kx-mode-label">{role === "lp" ? "Liquidity" : "Credit"}</span>
        )}
        <nav className="kx-nav">
          {nav.map((item) => (
            <Link
              key={item.href}
              href={withRole(item.href, role)}
              className={pathname === item.href ? "kx-nav-link is-active" : "kx-nav-link"}
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="kx-top-right">
          <ThemeToggle />
          <ConnectButton />
        </div>
      </header>
      <div className="kx-strip">
        <span className="kx-strip-env">
          <span className="kx-monad-dot" aria-hidden />
          {onMainnet ? "MAINNET · 143" : "MONAD TESTNET · 10143"}
          {block !== undefined ? ` · #${block.toString()}` : ""}
          {!onMainnet && health.data && !health.data.monad.rpc_ok ? " · network down" : ""}
        </span>
        <NetworkSwitch />
        <span className="kx-strip-book">
          BTC / ETH CREDIT
          <strong> TVL {usd(book.tvl)}</strong>
          <span> · ALLOC {usd(book.allocated)}</span>
          <span> · UTIL {pct(book.utilPct, 0)}</span>
          <span> · RISK {book.riskLevel}</span>
          {isConnected && address ? ` · ${compact(address)}` : ""}
        </span>
        {onMainnet ? (
          <span>Kredxo vault is on testnet 10143. Mainnet venues are documented, not funded.</span>
        ) : null}
      </div>
      <main className="kx-main">{children}</main>
      <footer className="kx-footer">
        <span>
          <strong>KREDXO</strong> · Adaptive Credit Infrastructure for Onchain Markets
        </span>
        <Link href={withRole("/demo", role)} className="kx-footer-link">
          View sitting
        </Link>
        <span>Monad Testnet 10143</span>
      </footer>
    </div>
  );
}
