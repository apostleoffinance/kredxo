export function Metric({
  label,
  value,
  hint,
  tone,
}: {
  label: string;
  value: string;
  hint?: string;
  tone?: "default" | "good" | "warn" | "bad";
}) {
  const color =
    tone === "good"
      ? "text-emerald-300"
      : tone === "warn"
        ? "text-amber-300"
        : tone === "bad"
          ? "text-red-300"
          : "text-zinc-100";
  return (
    <div className="kx-metric">
      <p className="kx-kicker">{label}</p>
      <p className={`kx-value ${color}`}>{value}</p>
      {hint ? <p className="kx-hint">{hint}</p> : null}
    </div>
  );
}
