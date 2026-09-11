export function RiskBadge({ state }: { state?: string }) {
  const level = state ?? "—";
  const tone =
    level === "LOW" || level === "NORMAL"
      ? "good"
      : level === "ELEVATED"
        ? "warn"
        : level === "HIGH" || level === "CRITICAL"
          ? "bad"
          : "default";

  return <span className={`kx-badge is-${tone}`}>{level}</span>;
}
