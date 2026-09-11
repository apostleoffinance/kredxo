export function Metric({
  label,
  value,
  hint,
  tone,
}: {
  label: string;
  value: string;
  hint?: string;
  tone?: "default" | "good" | "warn" | "bad" | "intel" | "enforce";
}) {
  const box =
    tone === "intel" ? "kx-metric is-intel" : tone === "enforce" ? "kx-metric is-enforce" : "kx-metric";
  const valueTone =
    tone === "good" || tone === "warn" || tone === "bad" ? `kx-value is-${tone}` : "kx-value";

  return (
    <div className={box}>
      <p className="kx-kicker">{label}</p>
      <p className={valueTone}>{value}</p>
      {hint ? <p className="kx-hint">{hint}</p> : null}
    </div>
  );
}
