export default function Footer() {
  return (
    <footer className="border-t border-white/5 py-12">
      <div className="mx-auto max-w-7xl px-4 sm:px-6">
        <div className="flex flex-col items-center gap-6 sm:flex-row sm:justify-between">
          <div>
            <span className="text-sm font-black tracking-tight text-white">
              FINAL EVOLUTION
              <span className="ml-2 text-[0.65rem] font-normal text-fel-cyan/80">GROUP</span>
            </span>
            <p className="mt-1 text-xs text-white/35">
              Clinical movement education — not medical diagnosis.
            </p>
          </div>
          <nav className="flex flex-wrap items-center gap-4 text-[0.6rem] font-bold uppercase tracking-[0.2em] text-white/50">
            <a href="/play/" className="hover:text-fel-cyan">PWA Lab</a>
            <a href="/shop/" className="hover:text-fel-cyan">Shop</a>
            <a href="/wallet/" className="hover:text-fel-cyan">Wallet</a>
          </nav>
        </div>
        <p className="mt-8 text-center text-[0.65rem] text-white/25">
          &copy; {new Date().getFullYear()} Final Evolution Group. finalevolutiongroup.com
        </p>
      </div>
    </footer>
  );
}
