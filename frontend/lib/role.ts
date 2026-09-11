export type Role = "lp" | "trader";

export const ROLE_KEY = "kredxo-role";

export const LP_NAV = [{ href: "/market", label: "Market" }] as const;

export const TRADER_NAV = [
  { href: "/profile", label: "Profile" },
  { href: "/account", label: "Account" },
  { href: "/trade", label: "Execute" },
  { href: "/risk", label: "Risk" },
] as const;

export const LP_HIDDEN = new Set(["/demo", "/profile", "/account", "/trade", "/risk"]);

export function parseRole(value: string | null | undefined): Role | null {
  if (value === "lp" || value === "trader") return value;
  return null;
}

export function navFor(role: Role) {
  return role === "lp" ? LP_NAV : TRADER_NAV;
}

export function withRole(href: string, role: Role) {
  return `${href}?role=${role}`;
}

export function persistRole(role: Role) {
  try {
    localStorage.setItem(ROLE_KEY, role);
  } catch {
    /* ignore quota / private mode */
  }
}
