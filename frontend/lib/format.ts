export function usd(value: string | number | null | undefined): string {
  const n = Number(value ?? 0);
  if (!Number.isFinite(n)) return "—";
  return n.toLocaleString("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: n >= 100 ? 0 : 2,
  });
}

export function pct(value: string | number | null | undefined, digits = 1): string {
  const n = Number(value ?? 0);
  if (!Number.isFinite(n)) return "—";
  return `${(n * 100).toFixed(digits)}%`;
}

export function compact(addr: string): string {
  if (!addr || addr.length < 12) return addr;
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

export function units6(value: bigint | undefined | null): number | null {
  return value === undefined || value === null ? null : Number(value) / 1e6;
}

export function sameAddr(a?: string | null, b?: string | null): boolean {
  return Boolean(a && b && a.toLowerCase() === b.toLowerCase());
}

export const RISK_LEVELS = ["LOW", "NORMAL", "ELEVATED", "HIGH", "CRITICAL"] as const;

export function riskLevelName(level: number | bigint | undefined | null): string {
  if (level === undefined || level === null) return "—";
  const i = Number(level);
  return RISK_LEVELS[i] ?? "—";
}

export function leverageLabel(value: string | number | null | undefined): string {
  const n = Number(value ?? 0);
  if (!Number.isFinite(n) || n === 0) return "—";
  return `${n.toFixed(n % 1 === 0 ? 0 : 1)}x`;
}
