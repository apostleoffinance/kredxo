"use client";

import { useEffect, useState } from "react";

import { applyTheme, readTheme, THEME_EVENT, type Theme } from "@/lib/theme";

export function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>("dark");

  useEffect(() => {
    const sync = () => setTheme(readTheme());
    sync();
    window.addEventListener(THEME_EVENT, sync);
    return () => window.removeEventListener(THEME_EVENT, sync);
  }, []);

  const next = theme === "dark" ? "light" : "dark";

  return (
    <button
      type="button"
      className="kx-icon-btn"
      aria-label={`Switch to ${next} theme`}
      title={`Switch to ${next}`}
      onClick={() => applyTheme(next)}
    >
      ◐
    </button>
  );
}
