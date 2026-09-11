"use client";

import type { Role } from "@/lib/role";

export function RoleToggle({
  role,
  setRole,
}: {
  role: Role;
  setRole: (next: Role) => void;
}) {
  return (
    <div className="kx-mode" role="group" aria-label="Product mode">
      <button
        type="button"
        className={role === "trader" ? "kx-mode-btn is-on" : "kx-mode-btn"}
        onClick={() => setRole("trader")}
      >
        Credit
      </button>
      <button
        type="button"
        className={role === "lp" ? "kx-mode-btn is-on" : "kx-mode-btn"}
        onClick={() => setRole("lp")}
      >
        Liquidity
      </button>
    </div>
  );
}
