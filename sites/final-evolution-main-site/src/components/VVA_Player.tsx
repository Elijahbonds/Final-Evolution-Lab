import { useCallback, useEffect, useMemo, useRef, useState } from "react";

/** Neural Cyan — matches Tailwind `fel-cyan` / lab HUD. */
const NEURAL_CYAN = "#5ce1e6";

export type VVAModule = {
  id: number;
  title: string;
  /** Voiceover script (Web Speech API). */
  script: string;
  /** Spiral Line lecture — full-width waveform (Neural Cyan). */
  spiralLineLecture: boolean;
};

const MODULES: VVAModule[] = [
  {
    id: 1,
    title: "Penultimate rhythm",
    script:
      "Module one: penultimate rhythm. The stride before takeoff is your clock. Align ground contact with the sixteen point six millisecond lab frame so stiffness and drive stay phase-locked.",
    spiralLineLecture: false,
  },
  {
    id: 2,
    title: "Spiral line / fascial plane",
    script:
      "Module two: the spiral line. Fascial continuity routes load from foot through hip to shoulder. Trace the cyan spiral in your mind — this is the lecture plane for elastic recoil, not isolation.",
    spiralLineLecture: true,
  },
  {
    id: 3,
    title: "Reactive stiffness lab",
    script:
      "Module three: reactive stiffness measured in kilonewtons per meter. Too soft, you leak energy. Too rigid, you shatter timing. Find the band that matches your sport and surface.",
    spiralLineLecture: false,
  },
  {
    id: 4,
    title: "Neural drive meter",
    script:
      "Module four: neural drive percent. This is intent, not fatigue alone. Drive should peak inside the penultimate window — not before, not after.",
    spiralLineLecture: false,
  },
  {
    id: 5,
    title: "Eccentric braking",
    script:
      "Module five: eccentric braking. Control the descent before you explode. The lab measures how fast you decelerate into the next impulse.",
    spiralLineLecture: false,
  },
  {
    id: 6,
    title: "Collagen recoil window",
    script:
      "Module six: collagen recoil. Tissue has a timing budget. Miss the window and you are fighting viscosity instead of elasticity.",
    spiralLineLecture: false,
  },
  {
    id: 7,
    title: "Ground reaction vector",
    script:
      "Module seven: ground reaction vector. Force is a vector, not a score. Aim magnitude and direction together — sagittal bias is not always correct.",
    spiralLineLecture: false,
  },
  {
    id: 8,
    title: "Fascial sequencing",
    script:
      "Module eight: fascial sequencing. Segments fire in order. When one link is congested, the graph shows red — fix upstream before you chase symptoms.",
    spiralLineLecture: false,
  },
  {
    id: 9,
    title: "Return-to-play gate",
    script:
      "Module nine: return to play gate. Clear objective thresholds before competition. The lab is education, not a clearance certificate — your clinician decides.",
    spiralLineLecture: false,
  },
  {
    id: 10,
    title: "Program integration",
    script:
      "Module ten: bringing it together — training, review, and progression in one workflow. For education only; not medical advice.",
    spiralLineLecture: false,
  },
];

function SpiralLineWaveform({ active }: { active: boolean }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const c = canvasRef.current;
    if (!c) return;
    const ctx = c.getContext("2d");
    if (!ctx) return;
    let raf = 0;
    let t = 0;
    const draw = () => {
      const w = c.width;
      const h = c.height;
      ctx.fillStyle = "rgba(2,2,3,0.85)";
      ctx.fillRect(0, 0, w, h);
      ctx.strokeStyle = NEURAL_CYAN;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      const mid = h * 0.5;
      for (let x = 0; x < w; x++) {
        const p = (x / w) * Math.PI * 8 + t;
        const y = mid + Math.sin(p) * (h * 0.28) + Math.sin(p * 0.31 + t) * (h * 0.08);
        if (x === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.shadowColor = NEURAL_CYAN;
      ctx.shadowBlur = active ? 12 : 4;
      ctx.stroke();
      ctx.shadowBlur = 0;
      t += active ? 0.14 : 0.04;
      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [active]);

  return (
    <div className="mt-4 overflow-hidden rounded-xl border border-fel-cyan/40 bg-black/60">
      <canvas ref={canvasRef} width={720} height={120} className="h-24 w-full max-w-full" />
      <p className="border-t border-fel-cyan/20 px-3 py-2 text-[0.6rem] uppercase tracking-[0.25em] text-fel-cyan/80">
        Spiral line · Neural Cyan waveform
      </p>
    </div>
  );
}

/**
 * Vertical Velocity Academy — ten modules, automated voiceover (speech synthesis), Spiral Line waveform on module 2.
 */
export function VVA_Player({ className = "" }: { className?: string }) {
  const [index, setIndex] = useState(0);
  const [speaking, setSpeaking] = useState(false);
  const mod = MODULES[index]!;

  const canSpeak = useMemo(
    () => typeof window !== "undefined" && "speechSynthesis" in window,
    []
  );

  const stopSpeech = useCallback(() => {
    if (canSpeak) window.speechSynthesis.cancel();
    setSpeaking(false);
  }, [canSpeak]);

  const speakCurrent = useCallback(() => {
    if (!canSpeak) return;
    stopSpeech();
    const u = new SpeechSynthesisUtterance(mod.script);
    u.rate = 0.96;
    u.pitch = 1;
    u.onend = () => setSpeaking(false);
    u.onerror = () => setSpeaking(false);
    setSpeaking(true);
    window.speechSynthesis.speak(u);
  }, [canSpeak, mod.script, stopSpeech]);

  useEffect(() => {
    return () => {
      if (canSpeak) window.speechSynthesis.cancel();
    };
  }, [canSpeak]);

  return (
    <div
      className={`rounded-2xl border border-fel-cyan/35 bg-black/55 p-6 backdrop-blur-md sm:p-8 ${className}`}
    >
      <p className="text-[0.6rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
        Academy
      </p>
      <h3 className="mt-2 text-xl font-black text-white sm:text-2xl">Ten guided modules</h3>
      <p className="mt-2 text-sm text-white/50">
        Optional audio uses your browser. Not medical advice.
      </p>

      <div className="mt-6 flex flex-wrap gap-2">
        {MODULES.map((m, i) => (
          <button
            key={m.id}
            type="button"
            onClick={() => {
              stopSpeech();
              setIndex(i);
            }}
            className={`rounded-full border px-3 py-1.5 text-[0.65rem] font-semibold uppercase tracking-wide transition ${
              i === index
                ? "border-fel-cyan bg-fel-cyan/15 text-fel-cyan"
                : "border-white/20 text-white/55 hover:border-white/40"
            }`}
          >
            {m.id}. {m.title}
          </button>
        ))}
      </div>

      <div className="mt-6 rounded-xl border border-white/10 bg-black/40 p-4">
        <p className="font-mono text-[0.7rem] text-fel-cyan/90">{mod.title}</p>
        <p className="mt-3 text-sm leading-relaxed text-white/75">{mod.script}</p>
      </div>

      {mod.spiralLineLecture ? <SpiralLineWaveform active={speaking} /> : null}

      <div className="mt-6 flex flex-wrap gap-3">
        <button
          type="button"
          onClick={speakCurrent}
          disabled={!canSpeak}
          className="inline-flex min-h-[48px] items-center justify-center rounded-full bg-fel-cyan px-8 text-sm font-black uppercase tracking-wide text-black shadow-[0_0_24px_rgba(92,225,230,0.35)] transition hover:bg-fel-cyan/90 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {speaking ? "Speaking…" : "Play voiceover"}
        </button>
        <button
          type="button"
          onClick={stopSpeech}
          className="rounded-full border border-white/25 px-6 py-3 text-sm font-semibold text-white/80 transition hover:bg-white/10"
        >
          Stop
        </button>
      </div>
      {!canSpeak ? <p className="mt-3 text-xs text-amber-400/90">Speech synthesis unavailable.</p> : null}
    </div>
  );
}
