import { useState } from "react";

const links = [
  { label: "Arena", href: "#arena" },
  { label: "PRQ", href: "#prq" },
  { label: "Academy", href: "#academy" },
  { label: "Streaming", href: "#streaming" },
  { label: "Shop", href: "#shop" },
  { label: "Install", href: "#install" },
];

export default function Nav() {
  const [open, setOpen] = useState(false);
  return (
    <header className="fixed top-0 left-0 right-0 z-50 border-b border-white/10 bg-fel-black/80 backdrop-blur-md">
      <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3 sm:px-6">
        <a href="/" className="flex items-center gap-2 text-sm font-black tracking-tight">
          FINAL EVOLUTION
          <span className="text-[0.65rem] font-normal text-fel-cyan/80">GROUP</span>
        </a>
        <nav className="hidden items-center gap-5 text-[0.6rem] font-bold uppercase tracking-[0.2em] text-white/70 md:flex">
          {links.map((l) => (
            <a key={l.href} href={l.href} className="transition hover:text-fel-cyan">
              {l.label}
            </a>
          ))}
        </nav>
        <button
          type="button"
          onClick={() => setOpen(!open)}
          className="flex h-8 w-8 items-center justify-center rounded-md border border-white/10 md:hidden"
          aria-label="Menu"
        >
          <span className="block h-0.5 w-4 bg-white/70" />
        </button>
      </div>
      {open && (
        <nav className="flex flex-col gap-3 border-t border-white/10 bg-fel-black/95 px-4 py-4 md:hidden">
          {links.map((l) => (
            <a
              key={l.href}
              href={l.href}
              onClick={() => setOpen(false)}
              className="text-sm font-bold uppercase tracking-wider text-white/80 hover:text-fel-cyan"
            >
              {l.label}
            </a>
          ))}
        </nav>
      )}
    </header>
  );
}
