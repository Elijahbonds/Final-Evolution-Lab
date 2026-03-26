import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { elevenLabsConfigured, playElevenLabsTts } from "../services/elevenLabsTts";

/** Neural Cyan — matches Tailwind `fel-cyan` / lab HUD. */
const NEURAL_CYAN = "#5ce1e6";

export type VVAModule = {
  id: number;
  title: string;
  script: string;
  spiralLineLecture: boolean;
};

const MODULES: VVAModule[] = [
  {
    id: 1,
    title: "CNS Freeway",
    script:
      "Module one: central nervous system readiness — timing, coordination, and the signal quality that lets you express force without fighting yourself.",
    spiralLineLecture: false,
  },
  {
    id: 2,
    title: "SFMA / FMS screening",
    script:
      "Module two: screening layers that map movement restriction to strategy — so you train what actually limits performance.",
    spiralLineLecture: false,
  },
  {
    id: 3,
    title: "Slings & spiral line",
    script:
      "Module three: how load travels through the body’s elastic chains — from foot through hip to shoulder — for recoil, not isolation.",
    spiralLineLecture: true,
  },
  {
    id: 4,
    title: "Correctives",
    script:
      "Module four: re-patterning drills that clear the path for power — address the constraint, then reload the pattern.",
    spiralLineLecture: false,
  },
  {
    id: 5,
    title: "Penultimate rhythm",
    script:
      "Module five: the last step before takeoff — rhythm and foot strike that set up your jump.",
    spiralLineLecture: false,
  },
  {
    id: 6,
    title: "Reactive stiffness",
    script:
      "Module six: spring-like quality of the leg — tuned to surface, sport, and how you intend to land.",
    spiralLineLecture: false,
  },
  {
    id: 7,
    title: "Neural drive optimization",
    script:
      "Module seven: intent and effort in the right window — drive is about timing and quality, not only fatigue.",
    spiralLineLecture: false,
  },
  {
    id: 8,
    title: "Eccentric control",
    script:
      "Module eight: deceleration before acceleration — own the descent before you explode upward.",
    spiralLineLecture: false,
  },
  {
    id: 9,
    title: "Elastic recoil",
    script:
      "Module nine: hop progressions and tissue timing — elasticity depth, not just volume.",
    spiralLineLecture: false,
  },
  {
    id: 10,
    title: "Ground reaction & vectors",
    script:
      "Module ten: force has direction — aim magnitude and direction together for the task.",
    spiralLineLecture: false,
  },
  {
    id: 11,
    title: "Return-to-play progression",
    script:
      "Module eleven: objective thresholds before competition — education and metrics; your clinician clears you for sport.",
    spiralLineLecture: false,
  },
  {
    id: 12,
    title: "Flight protocol",
    script:
      "Module twelve: continuous hops and elasticity depth — tying the curriculum to repeatable, measurable performance.",
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
        Spiral line · movement waveform
      </p>
    </div>
  );
}

/**
 * Academy modules — ElevenLabs voice when configured; otherwise browser speech synthesis.
 */
export function VVA_Player({ className = "" }: { className?: string }) {
  const [index, setIndex] = useState(0);
  const [speaking, setSpeaking] = useState(false);
  const [voiceError, setVoiceError] = useState<string | null>(null);
  const mod = MODULES[index]!;
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const useEleven = useMemo(() => elevenLabsConfigured(), []);
  const canSpeak = useMemo(
    () => useEleven || (typeof window !== "undefined" && "speechSynthesis" in window),
    [useEleven]
  );

  const stopSpeech = useCallback(() => {
    abortRef.current?.abort();
    abortRef.current = null;
    if (typeof window !== "undefined" && "speechSynthesis" in window) {
      window.speechSynthesis.cancel();
    }
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.src = "";
      audioRef.current = null;
    }
    setSpeaking(false);
  }, []);

  const speakCurrent = useCallback(async () => {
    setVoiceError(null);
    stopSpeech();
    setSpeaking(true);

    if (useEleven) {
      try {
        abortRef.current = new AbortController();
        const audio = await playElevenLabsTts(mod.script, abortRef.current.signal);
        audioRef.current = audio;
        audio.addEventListener(
          "ended",
          () => {
            setSpeaking(false);
            audioRef.current = null;
          },
          { once: true }
        );
      } catch (e) {
        setVoiceError(e instanceof Error ? e.message : "Playback failed");
        setSpeaking(false);
      }
      return;
    }

    if (!("speechSynthesis" in window)) {
      setSpeaking(false);
      return;
    }
    const u = new SpeechSynthesisUtterance(mod.script);
    u.rate = 0.96;
    u.pitch = 1;
    u.onend = () => setSpeaking(false);
    u.onerror = () => setSpeaking(false);
    window.speechSynthesis.speak(u);
  }, [mod.script, stopSpeech, useEleven]);

  useEffect(() => {
    return () => stopSpeech();
  }, [stopSpeech]);

  return (
    <div
      className={`rounded-2xl border border-fel-cyan/35 bg-black/55 p-6 backdrop-blur-md sm:p-8 ${className}`}
    >
      <p className="text-[0.6rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">Academy</p>
      <h3 className="mt-2 text-xl font-black text-white sm:text-2xl">Twelve guided modules</h3>
      <p className="mt-2 text-sm text-white/50">
        {useEleven
          ? "Narration uses your ElevenLabs voice profile. Not medical advice."
          : "Optional narration uses your browser voice, or add ElevenLabs keys in the site environment. Not medical advice."}
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
          onClick={() => void speakCurrent()}
          disabled={!canSpeak}
          className="inline-flex min-h-[48px] items-center justify-center rounded-full bg-fel-cyan px-8 text-sm font-black uppercase tracking-wide text-black shadow-[0_0_24px_rgba(92,225,230,0.35)] transition hover:bg-fel-cyan/90 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {speaking ? "Playing…" : "Play narration"}
        </button>
        <button
          type="button"
          onClick={stopSpeech}
          className="rounded-full border border-white/25 px-6 py-3 text-sm font-semibold text-white/80 transition hover:bg-white/10"
        >
          Stop
        </button>
      </div>
      {!canSpeak ? (
        <p className="mt-3 text-xs text-amber-400/90">Narration is unavailable in this browser.</p>
      ) : null}
      {voiceError ? (
        <p className="mt-3 text-xs text-amber-400/90" role="alert">
          {voiceError}
        </p>
      ) : null}
    </div>
  );
}
