import React, { useState, useEffect } from "react";
import MedicalDisclaimerView from "./components/MedicalDisclaimerView";

const STORAGE_KEY = "felHasAcceptedMedicalDisclaimer";

const App: React.FC = () => {
  const [hasAccepted, setHasAccepted] = useState<boolean>(false);

  useEffect(() => {
    try {
      if (localStorage.getItem(STORAGE_KEY) === "true") {
        setHasAccepted(true);
      }
    } catch {
      /* private mode */
    }
  }, []);

  const handleAccept = () => {
    try {
      localStorage.setItem(STORAGE_KEY, "true");
    } catch {
      /* ignore */
    }
    setHasAccepted(true);
  };

  return (
    <div className="min-h-screen bg-black text-white font-sans antialiased">
      {!hasAccepted && <MedicalDisclaimerView onAccept={handleAccept} />}

      <main
        className={`transition-opacity duration-500 min-h-screen ${
          hasAccepted ? "opacity-100" : "opacity-0 pointer-events-none"
        }`}
      >
        <header className="p-6 border-b border-cyan-900/30 flex flex-wrap justify-between items-center gap-4">
          <h1 className="text-xl font-bold tracking-tight text-cyan-400">
            FINAL EVOLUTION LAB{" "}
            <span className="text-xs font-normal opacity-50 ml-2">v1.0.0</span>
          </h1>
          <div className="px-3 py-1 bg-cyan-950/50 border border-cyan-500/30 rounded-full text-xs text-cyan-300">
            SOVEREIGN WALLET: <span id="shard-count">0</span> SHARDS
          </div>
        </header>

        <section className="p-8 grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="p-6 bg-zinc-900/50 border border-zinc-800 rounded-2xl">
            <h2 className="text-sm font-semibold uppercase tracking-widest text-zinc-500 mb-4">Neural Drive</h2>
            <div className="h-48 flex items-end gap-2">
              {[40, 70, 45, 90, 65, 80, 50].map((h, i) => (
                <div
                  key={i}
                  className="flex-1 bg-cyan-500/20 border-t-2 border-cyan-400 rounded-t min-h-[8px]"
                  style={{ height: `${h}%` }}
                />
              ))}
            </div>
          </div>

          <div className="p-6 bg-zinc-900/50 border border-zinc-800 rounded-2xl">
            <h2 className="text-sm font-semibold uppercase tracking-widest text-zinc-500 mb-4">Ankle Piston</h2>
            <div className="flex flex-col gap-4">
              <div className="flex justify-between text-xs">
                <span>REACTIVE STIFFNESS</span>
                <span className="text-cyan-400">2.4 kN/m</span>
              </div>
              <div className="w-full h-2 bg-zinc-800 rounded-full overflow-hidden">
                <div className="w-[70%] h-full bg-cyan-400 rounded-full" />
              </div>
            </div>
          </div>
        </section>

        <div className="fixed bottom-8 right-8">
          <button
            type="button"
            className="px-8 py-4 bg-cyan-500 text-black font-bold rounded-full hover:bg-cyan-400 transition-colors shadow-[0_0_20px_rgba(34,211,238,0.35)]"
          >
            INITIALIZE SCAN
          </button>
        </div>
      </main>
    </div>
  );
};

export default App;
