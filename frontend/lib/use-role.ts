"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useCallback, useEffect, useState } from "react";

import { LP_HIDDEN, parseRole, persistRole, ROLE_KEY, type Role } from "./role";

export function useRole() {
  const search = useSearchParams();
  const pathname = usePathname();
  const router = useRouter();
  const fromQuery = parseRole(search.get("role"));
  const [fromStore, setFromStore] = useState<Role | null>(null);

  useEffect(() => {
    setFromStore(parseRole(localStorage.getItem(ROLE_KEY)));
  }, []);

  useEffect(() => {
    if (!fromQuery) return;
    persistRole(fromQuery);
    setFromStore(fromQuery);
  }, [fromQuery]);

  const role: Role = fromQuery ?? fromStore ?? "trader";

  const setRole = useCallback(
    (next: Role) => {
      persistRole(next);
      setFromStore(next);
      const dest =
        next === "lp" && LP_HIDDEN.has(pathname)
          ? "/market"
          : next === "trader" && pathname === "/market"
            ? "/account"
            : pathname;
      router.replace(`${dest}?role=${next}`);
    },
    [pathname, router],
  );

  return { role, setRole };
}
