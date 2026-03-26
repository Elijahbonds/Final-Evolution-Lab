/**
 * In-page anchor navigation — works with SPA (`/*` → `index.html` on Netlify).
 */
const LINKS = [
  { href: "#prq", label: "PRQ" },
  { href: "#system-scan", label: "System Scan" },
  { href: "#academy", label: "12-Module Academy" },
  { href: "#arena", label: "Arena" },
  { href: "#fel-lab", label: "Readiness dashboard" },
  { href: "#sovereign-access", label: "Checkout" },
] as const;

export function SiteNav() {
  return (
    <nav
      className="sticky top-0 z-[100] border-b border-white/10 bg-fel-black/90 px-4 py-3 backdrop-blur-md sm:px-8"
      aria-label="Primary"
    >
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-center gap-x-6 gap-y-2">
        {LINKS.map(({ href, label }) => (
          <a
            key={href}
            href={href}
            className="text-[0.7rem] font-semibold uppercase tracking-[0.2em] text-white/50 transition hover:text-fel-cyan"
          >
            {label}
          </a>
        ))}
      </div>
    </nav>
  );
}
