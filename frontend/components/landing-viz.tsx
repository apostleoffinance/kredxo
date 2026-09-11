"use client";

import { BrandMark } from "@/components/brand-mark";

const NODES = [
  { id: "history", label: "HISTORY", x: 280, y: 36 },
  { id: "risk", label: "RISK", x: 72, y: 248 },
  { id: "policy", label: "POLICY", x: 488, y: 248 },
  { id: "exec", label: "EXECUTION", x: 280, y: 452 },
] as const;

export function LandingViz() {
  return (
    <div className="kx-viz" aria-hidden>
      <svg className="kx-viz-svg" viewBox="0 0 560 488" fill="none">
        <defs>
          <pattern id="kx-grid" width="28" height="28" patternUnits="userSpaceOnUse">
            <path d="M28 0H0V28" stroke="currentColor" strokeOpacity="0.09" />
          </pattern>
        </defs>
        <rect width="560" height="488" fill="url(#kx-grid)" />

        <path className="kx-viz-path" d="M280 52 L280 188" />
        <path className="kx-viz-path" d="M280 300 L280 436" />
        <path className="kx-viz-path" d="M88 248 L204 248" />
        <path className="kx-viz-path" d="M356 248 L472 248" />
        <path className="kx-viz-path kx-viz-path-soft" d="M280 188 C 210 188 180 210 88 248" />
        <path className="kx-viz-path kx-viz-path-soft" d="M280 188 C 350 188 380 210 472 248" />
        <path className="kx-viz-path kx-viz-path-soft" d="M88 248 C 180 300 210 300 280 300" />
        <path className="kx-viz-path kx-viz-path-soft" d="M472 248 C 380 300 350 300 280 300" />

        <circle className="kx-viz-dot" r="2.2">
          <animateMotion dur="7.5s" repeatCount="indefinite" path="M280 52 L280 188" />
        </circle>
        <circle className="kx-viz-dot" r="2.2">
          <animateMotion dur="9s" repeatCount="indefinite" path="M88 248 C 180 300 210 300 280 300 L280 436" />
        </circle>
        <circle className="kx-viz-dot" r="2.2">
          <animateMotion dur="8.2s" repeatCount="indefinite" path="M472 248 C 380 300 350 300 280 300" />
        </circle>

        {NODES.map((n) => (
          <g key={n.id}>
            <circle cx={n.x} cy={n.y} r="3" className="kx-viz-node" />
            <text x={n.x} y={n.y + (n.y < 80 ? -12 : 16)} className="kx-viz-label" textAnchor="middle">
              {n.label}
            </text>
          </g>
        ))}

        <text x="28" y="20" className="kx-viz-meta">
          CREDIT CAPACITY
        </text>
        <text x="430" y="20" className="kx-viz-meta">
          RISK STATE
        </text>
        <text x="28" y="476" className="kx-viz-meta">
          SETTLEMENT
        </text>
        <text x="456" y="476" className="kx-viz-meta">
          POLICY
        </text>
      </svg>
      <div className="kx-viz-hub">
        <BrandMark size={132} className="kx-viz-mark" />
      </div>
    </div>
  );
}
