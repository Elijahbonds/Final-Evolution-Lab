/**
 * MusicMode — WebAudio track-based loop editor + deterministic composer challenge.
 *
 * Built on the creative-models foundation (docs/creative_models.md):
 *   - POST /api/music/projects (create, seed persisted)
 *   - POST /api/music/projects/{id}/export (JSON export)
 *   - POST /api/music/projects/{id}/auto-generate (deterministic beat/harmony)
 *   - POST /api/music/composer-challenge/generate|score (seeded scoring)
 *   - POST /api/music/projects/{id}/save-as-pack (Creator-Card-shaped payload)
 *
 * Export: one button -> (a) project JSON from the backend, (b) in-browser WAV
 * via OfflineAudioContext. The exported JSON re-imports to identical playback.
 *
 * ?recording=1 (RECORDING_LOCAL): locally-authoritative, seed visible, so a
 * solo user can record composing + playing + exporting a loop smoothly.
 *
 * Accessibility (second pass): the beat grid is a keyboard-operable ARIA grid
 * (roving tabindex, arrows/space/enter), every control has an accessible name,
 * status + score are polite live regions, motion respects prefers-reduced-motion,
 * and muted greys were lifted to WCAG AA contrast on the dark theme.
 */
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { generateComposition } from "@/lib/musicTheory";
import {
  scheduleProject, renderProjectToWav, INSTRUMENT_NAMES,
} from "@/lib/audioEngine";
import { useReducedMotion } from "@/lib/useReducedMotion";

const API_BASE = process.env.REACT_APP_BACKEND_URL || "";
const API = `${API_BASE}/api`;

const CYAN = "#00D4FF";
const PURPLE = "#9933FF";
// Contrast-lifted muted greys (WCAG AA on #08090b / #11151d). See a11y pass.
const MUTE = "#8b93a3";   // was #6b7280 (~4.35:1, failed)
const FAINT = "#7b8494";  // was #4b5563 (~2.5:1, failed)

const KEYS = ["C", "Cm", "D", "Dm", "E", "Em", "F", "F#m", "G", "Gm", "A", "Am", "Bb", "Bm"];
const GRID_BEATS = 16; // 4 bars of 4/4  — TODO(Elijah): default loop length is a taste call.
const STEP = 1;        // 1 beat per grid cell (beat-quantized placement)
const TRACK_COLORS = [CYAN, PURPLE, "#00E5A8", "#FFB800"];

const srOnly = {
  position: "absolute", width: 1, height: 1, padding: 0, margin: -1,
  overflow: "hidden", clip: "rect(0 0 0 0)", whiteSpace: "nowrap", border: 0,
};

const styles = {
  page: {
    background: "#08090b", color: "#e8eaf0", minHeight: "100vh",
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
    padding: "20px", boxSizing: "border-box",
  },
  header: { display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: 12, marginBottom: 16 },
  title: { fontSize: "1.5rem", fontWeight: 800, color: CYAN, margin: 0, letterSpacing: "0.02em" },
  sub: { fontSize: "0.75rem", color: MUTE, textTransform: "uppercase", letterSpacing: "0.15em" },
  panel: { background: "#0d1018", border: `1px solid rgba(0,212,255,0.15)`, borderRadius: 14, padding: 16, marginBottom: 16 },
  row: { display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap" },
  btn: (bg, fg = "#08090b") => ({
    minHeight: 44, minWidth: 44, padding: "10px 18px", borderRadius: 10, border: "none",
    background: bg, color: fg, fontWeight: 700, fontSize: "0.85rem", cursor: "pointer",
    letterSpacing: "0.03em", touchAction: "manipulation",
  }),
  ghost: {
    minHeight: 44, padding: "10px 16px", borderRadius: 10, cursor: "pointer",
    background: "transparent", color: "#e8eaf0", border: "1px solid rgba(255,255,255,0.18)",
    fontWeight: 600, fontSize: "0.85rem", touchAction: "manipulation",
  },
  select: {
    minHeight: 44, background: "#11151d", color: "#e8eaf0", border: "1px solid rgba(255,255,255,0.15)",
    borderRadius: 8, padding: "0 10px", fontSize: "0.85rem",
  },
  label: { fontSize: "0.7rem", color: MUTE, textTransform: "uppercase", letterSpacing: "0.1em", marginBottom: 4 },
  trackRow: { display: "flex", alignItems: "stretch", gap: 8, marginBottom: 8 },
  trackHead: (color) => ({
    width: 160, flexShrink: 0, display: "flex", flexDirection: "column", gap: 4, padding: 8,
    background: "#11151d", borderRadius: 8, borderLeft: `3px solid ${color}`,
  }),
  grid: { display: "grid", gridTemplateColumns: `repeat(${GRID_BEATS}, 1fr)`, gap: 3, flex: 1, minWidth: 0 },
  cell: (on, color, isBar, reduced) => ({
    minHeight: 44, borderRadius: 6, cursor: "pointer", touchAction: "manipulation",
    background: on ? color : "rgba(255,255,255,0.05)",
    border: isBar ? "1px solid rgba(255,255,255,0.16)" : "1px solid transparent",
    boxShadow: on && !reduced ? `0 0 10px ${color}66` : "none",
    transition: reduced ? "none" : "background 0.08s",
    padding: 0,
  }),
  playhead: { fontSize: "0.7rem", color: CYAN, fontFamily: "monospace" },
  seedTag: { fontFamily: "monospace", fontSize: "0.72rem", color: PURPLE, background: "rgba(153,51,255,0.12)", padding: "3px 8px", borderRadius: 6 },
  scoreBig: { fontSize: "2.4rem", fontWeight: 800, color: CYAN, lineHeight: 1 },
  bar: (v, color) => ({ height: 8, borderRadius: 4, background: color, width: `${Math.round(v * 100)}%`, minWidth: 2 }),
  barTrack: { height: 8, borderRadius: 4, background: "rgba(255,255,255,0.08)", flex: 1 },
};

const FOCUS_CSS = `
[data-testid="music-mode"] :is(button,select,input,[role="gridcell"]):focus-visible{
  outline:2px solid ${CYAN};outline-offset:2px;border-radius:6px;
  box-shadow:0 0 0 4px rgba(0,212,255,0.35);
}
[data-testid="music-mode"] :is(button,select,input,[role="gridcell"]):focus:not(:focus-visible){outline:none;}
`;

function newTrack(i) {
  const instrument = INSTRUMENT_NAMES[i % INSTRUMENT_NAMES.length];
  return {
    track_id: `trk_${Math.random().toString(36).slice(2, 10)}`,
    instrument,
    type: instrument === "drum-kit" ? "sample" : "instrument",
    clips: [],
    volume: 1, pan: 0, muted: false, effects: [],
  };
}

function makeSeed() {
  // 32-bit visible seed (kept small so it round-trips cleanly in the UI).
  return Math.floor(Math.random() * 0xffffffff) >>> 0;
}

export default function MusicMode({ recording: recordingProp } = {}) {
  const recording = recordingProp ||
    (typeof window !== "undefined" && new URLSearchParams(window.location.search).get("recording") === "1");

  const reducedMotion = useReducedMotion();

  const [seed, setSeed] = useState(makeSeed);
  const [bpm, setBpm] = useState(120);
  const [bpmText, setBpmText] = useState("120");
  const [musicKey, setMusicKey] = useState("Am");
  const [name, setName] = useState("Untitled Loop");
  const [tracks, setTracks] = useState(() => [newTrack(0), newTrack(1), newTrack(2), newTrack(3)]);
  const [metronome, setMetronome] = useState(false);
  const [looping, setLooping] = useState(true);
  const [playing, setPlaying] = useState(false);
  const [playBeat, setPlayBeat] = useState(-1);
  const [projectId, setProjectId] = useState(null);
  const [status, setStatus] = useState("");
  const [statusKind, setStatusKind] = useState("info"); // info | success | error
  const [challenge, setChallenge] = useState(null);
  const [score, setScore] = useState(null);
  const [wavUrl, setWavUrl] = useState(null);
  const [busy, setBusy] = useState(false);
  const [focus, setFocus] = useState({ row: 0, col: 0 });

  const ctxRef = useRef(null);
  const rafRef = useRef(null);
  const startAtRef = useRef(0);
  const scheduledEndRef = useRef(0);
  const activeCellRef = useRef(null);
  const wavUrlRef = useRef(null);

  const setMsg = useCallback((text, kind = "info") => { setStatus(text); setStatusKind(kind); }, []);

  // Deterministic composition derived from seed+key (auto-harmony source).
  const composition = useMemo(() => generateComposition(seed, musicKey, GRID_BEATS / 4), [seed, musicKey]);

  const project = useMemo(() => ({
    name, bpm, key: musicKey, seed,
    tracks: tracks.map((t) => ({
      track_id: t.track_id, type: t.type, instrument: t.instrument,
      clips: t.clips.map((c) => ({ start: c.start, length: c.length })),
      volume: t.volume, pan: t.pan, muted: t.muted, effects: t.effects || [],
    })),
    metronome, composition,
  }), [name, bpm, musicKey, seed, tracks, metronome, composition]);

  const isEmpty = useMemo(() => tracks.every((t) => t.clips.length === 0), [tracks]);

  const getCtx = () => {
    if (!ctxRef.current) ctxRef.current = new (window.AudioContext || window.webkitAudioContext)();
    return ctxRef.current;
  };

  const stop = useCallback(() => {
    setPlaying(false);
    setPlayBeat(-1);
    cancelAnimationFrame(rafRef.current);
    // Suspend (not close) so we reuse ONE context for the component's lifetime
    // instead of churning contexts on every play/stop (avoids browser limits).
    if (ctxRef.current && ctxRef.current.state === "running") {
      try { ctxRef.current.suspend(); } catch (_e) { /* noop */ }
    }
  }, []);

  const play = useCallback(async () => {
    cancelAnimationFrame(rafRef.current);
    const ctx = getCtx();
    if (ctx.state === "suspended") { try { await ctx.resume(); } catch (_e) { /* noop */ } }
    const spb = 60 / bpm;
    const loopLen = GRID_BEATS * spb;
    const startAt = ctx.currentTime + 0.08;
    startAtRef.current = startAt;
    const passes = looping ? 4 : 1;
    for (let p = 0; p < passes; p++) scheduleProject(ctx, project, startAt + p * loopLen);
    scheduledEndRef.current = startAt + passes * loopLen;
    setPlaying(true);
    setPlayBeat(0);
    const tick = () => {
      const elapsed = ctx.currentTime - startAt;
      if (elapsed < 0) { rafRef.current = requestAnimationFrame(tick); return; }
      // Stop the visual playhead once all scheduled passes have elapsed so it
      // never keeps chasing over silence.
      if (ctx.currentTime >= scheduledEndRef.current) { stop(); return; }
      const beat = Math.floor((elapsed / spb) % GRID_BEATS);
      setPlayBeat(beat);
      rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
  }, [bpm, looping, project, stop]);

  useEffect(() => () => {
    cancelAnimationFrame(rafRef.current);
    if (ctxRef.current) { try { ctxRef.current.close(); } catch (_e) { /* noop */ } ctxRef.current = null; }
    if (wavUrlRef.current) URL.revokeObjectURL(wavUrlRef.current);
  }, []);

  const toggleCell = useCallback((ti, beat) => {
    setTracks((prev) => prev.map((t, i) => {
      if (i !== ti) return t;
      const exists = t.clips.find((c) => c.start === beat);
      const clips = exists
        ? t.clips.filter((c) => c.start !== beat)
        : [...t.clips, { start: beat, length: STEP }].sort((a, b) => a.start - b.start);
      return { ...t, clips };
    }));
    setScore(null);
  }, []);

  const cellOn = (t, beat) => t.clips.some((c) => c.start === beat);

  const setTrackField = (ti, field, val) =>
    setTracks((prev) => prev.map((t, i) => {
      if (i !== ti) return t;
      const upd = { ...t, [field]: val };
      if (field === "instrument") upd.type = val === "drum-kit" ? "sample" : "instrument";
      return upd;
    }));

  // ── Keyboard grid navigation (roving tabindex) ──
  useEffect(() => {
    const el = activeCellRef.current;
    if (el && el.closest('[role="grid"]')?.contains(document.activeElement)) el.focus();
  }, [focus]);

  const onGridKeyDown = useCallback((e) => {
    const { row, col } = focus;
    const lastRow = tracks.length - 1;
    const lastCol = GRID_BEATS - 1;
    let next = null;
    switch (e.key) {
      case "ArrowRight": next = { row, col: Math.min(lastCol, col + 1) }; break;
      case "ArrowLeft": next = { row, col: Math.max(0, col - 1) }; break;
      case "ArrowDown": next = { row: Math.min(lastRow, row + 1), col }; break;
      case "ArrowUp": next = { row: Math.max(0, row - 1), col }; break;
      case "Home": next = e.ctrlKey ? { row: 0, col: 0 } : { row, col: 0 }; break;
      case "End": next = e.ctrlKey ? { row: lastRow, col: lastCol } : { row, col: lastCol }; break;
      case "PageUp": next = { row, col: Math.max(0, col - 4) }; break;
      case "PageDown": next = { row, col: Math.min(lastCol, col + 4) }; break;
      case " ":
      case "Enter":
        e.preventDefault(); toggleCell(row, col); return;
      default: return;
    }
    e.preventDefault();
    setFocus(next);
  }, [focus, tracks.length, toggleCell]);

  // ── Auto-beat / auto-harmony (deterministic) ──
  const autoGenerate = () => {
    const comp = generateComposition(seed, musicKey, GRID_BEATS / 4);
    setTracks((prev) => prev.map((t) => {
      if (t.instrument === "drum-kit") {
        const clips = [];
        for (let b = 0; b < GRID_BEATS / 4; b++) clips.push({ start: b * 4, length: 4 });
        return { ...t, clips };
      }
      const clips = comp.harmony.map((h) => ({ start: h.bar * 4, length: 4 }));
      return { ...t, clips };
    }));
    setMsg(`Auto-generated ${comp.genre} beat + harmony in ${comp.key}`, "success");
    setScore(null);
  };

  // ── Persist + export (JSON via backend + WAV in-browser) ──
  // Reuse a single server project per session instead of creating a new row on
  // every export/save.
  const ensureProject = useCallback(async () => {
    if (projectId) return projectId;
    const body = { name, bpm, key: musicKey, seed, tracks: project.tracks, metadata: { composition } };
    const r = await fetch(`${API}/music/projects`, {
      method: "POST", headers: { "Content-Type": "application/json" }, credentials: "include",
      body: JSON.stringify(body),
    });
    if (!r.ok) throw new Error(`create failed: ${r.status}`);
    const data = await r.json();
    setProjectId(data.project_id);
    return data.project_id;
  }, [projectId, name, bpm, musicKey, seed, project.tracks, composition]);

  const setWav = useCallback((url) => {
    if (wavUrlRef.current) URL.revokeObjectURL(wavUrlRef.current);
    wavUrlRef.current = url;
    setWavUrl(url);
  }, []);

  const exportAll = async () => {
    if (isEmpty) { setMsg("Add at least one clip before exporting", "error"); return; }
    setBusy(true);
    setMsg("Exporting…", "info");
    try {
      // (a) project JSON — reuse or create the server project; distinguish a
      // real HTTP error from an offline/network fallback.
      try {
        const pid = await ensureProject();
        const er = await fetch(`${API}/music/projects/${pid}/export`, { method: "POST", credentials: "include" });
        if (er.ok) {
          const exp = await er.json();
          downloadBlob(new Blob([JSON.stringify(exp, null, 2)], { type: "application/json" }), `${slug(name)}.json`);
        } else {
          throw new Error(`export ${er.status}`);
        }
      } catch (e) {
        // Offline / RECORDING_LOCAL: export the local project as JSON directly.
        downloadBlob(new Blob([JSON.stringify({ export_version: "1.0-local", project_type: "music", project }, null, 2)], { type: "application/json" }), `${slug(name)}.json`);
      }
      // (b) in-browser WAV render via OfflineAudioContext (deterministic).
      const wav = await renderProjectToWav(project);
      setWav(URL.createObjectURL(wav));
      downloadBlob(wav, `${slug(name)}.wav`);
      setMsg("Exported JSON + WAV", "success");
    } catch (e) {
      setMsg(`Export error: ${e.message}`, "error");
    } finally {
      setBusy(false);
    }
  };

  // ── Composer challenge ──
  const startChallenge = async () => {
    setBusy(true);
    const constraints = { bpm, key: musicKey, instruments: ["instrument", "sample"], length_beats: 16, max_tracks: 4 };
    try {
      const r = await fetch(`${API}/music/composer-challenge/generate`, {
        method: "POST", headers: { "Content-Type": "application/json" }, credentials: "include",
        body: JSON.stringify({ seed, constraints }),
      });
      const data = r.ok ? await r.json() : { challenge_id: `chal_local_${seed}`, seed, constraints };
      setChallenge(data);
      setMsg(`Challenge: ${data.brief || "compose the best loop for this seed"}`, "info");
    } catch (e) {
      setChallenge({ challenge_id: `chal_local_${seed}`, seed, constraints });
      setMsg("Challenge started (offline)", "info");
    } finally {
      setBusy(false);
    }
  };

  const submitChallenge = async () => {
    if (isEmpty) { setMsg("Add some clips before submitting", "error"); return; }
    setBusy(true);
    const constraints = challenge?.constraints || { bpm, key: musicKey, instruments: ["instrument", "sample"], length_beats: 16, max_tracks: 4 };
    try {
      const r = await fetch(`${API}/music/composer-challenge/score`, {
        method: "POST", headers: { "Content-Type": "application/json" }, credentials: "include",
        body: JSON.stringify({ seed, constraints, tracks: project.tracks, bpm, key: musicKey }),
      });
      if (!r.ok) throw new Error(`score ${r.status}`);
      setScore(await r.json());
      setMsg("Scored", "success");
    } catch (e) {
      setMsg(`Scoring error: ${e.message}`, "error");
    } finally {
      setBusy(false);
    }
  };

  // ── Save as pack (Creator-Card-shaped) ──
  const saveAsPack = async () => {
    setBusy(true);
    try {
      const pid = await ensureProject();
      const r = await fetch(`${API}/music/projects/${pid}/save-as-pack`, {
        method: "POST", headers: { "Content-Type": "application/json" }, credentials: "include",
        body: JSON.stringify({ card_id: "card_sampler_01" }),
      });
      if (!r.ok) throw new Error(`pack ${r.status}`);
      const data = await r.json();
      setMsg(`Saved pack "${data.pack.title}" · ${data.sample_count} samples`, "success");
    } catch (e) {
      setMsg(`Save-as-pack error: ${e.message}`, "error");
    } finally {
      setBusy(false);
    }
  };

  const statusColor = statusKind === "error" ? "#fca5a5"
    : statusKind === "success" ? "#86efac" : "#c4b5fd";
  const statusBorder = statusKind === "error" ? "rgba(248,113,113,0.4)"
    : statusKind === "success" ? "rgba(52,211,153,0.35)" : "rgba(153,51,255,0.25)";

  return (
    <div style={styles.page} data-testid="music-mode">
      <style>{FOCUS_CSS}</style>

      <div style={styles.header}>
        <div>
          <h1 style={styles.title}>MUSIC CREATION</h1>
          <div style={styles.sub}>WebAudio Loop Editor · Composer Challenge</div>
        </div>
        <div style={styles.row}>
          {recording && <span style={{ ...styles.seedTag, color: CYAN, background: "rgba(0,212,255,0.12)" }}>REC · LOCAL</span>}
          <span style={styles.seedTag} data-testid="seed-tag">seed: {seed}</span>
          <button style={styles.ghost} onClick={() => { setSeed(makeSeed()); setScore(null); setMsg("Reseeded — re-run Auto-beat to apply the new progression", "info"); }} data-testid="reseed" aria-label="Reseed — new random seed">Reseed</button>
        </div>
      </div>

      {/* Transport + globals */}
      <div style={styles.panel}>
        <div style={styles.row}>
          {playing
            ? <button style={styles.btn(PURPLE, "#fff")} onClick={stop} data-testid="stop" aria-label="Stop playback">■ Stop</button>
            : <button style={styles.btn(CYAN)} onClick={play} data-testid="play" aria-label="Play loop">▶ Play</button>}
          <button style={{ ...styles.ghost, borderColor: looping ? CYAN : "rgba(255,255,255,0.18)", color: looping ? CYAN : "#e8eaf0" }} onClick={() => setLooping((v) => !v)} data-testid="loop" aria-pressed={looping} aria-label="Loop playback">Loop {looping ? "on" : "off"}</button>
          <button style={{ ...styles.ghost, borderColor: metronome ? CYAN : "rgba(255,255,255,0.18)", color: metronome ? CYAN : "#e8eaf0" }} onClick={() => setMetronome((v) => !v)} data-testid="metronome" aria-pressed={metronome} aria-label="Metronome click">Metronome {metronome ? "on" : "off"}</button>

          <div>
            <div style={styles.label} id="bpm-label">BPM</div>
            <input type="number" min={20} max={300} value={bpmText}
              onChange={(e) => { setBpmText(e.target.value); const n = Number(e.target.value); if (Number.isFinite(n) && n >= 20 && n <= 300) setBpm(n); }}
              onBlur={() => { const n = Math.max(20, Math.min(300, Number(bpmText) || 120)); setBpm(n); setBpmText(String(n)); }}
              style={{ ...styles.select, width: 78 }} data-testid="bpm" aria-label="Tempo in beats per minute" />
          </div>
          <div>
            <div style={styles.label}>Key</div>
            <select value={musicKey} onChange={(e) => { setMusicKey(e.target.value); setScore(null); }} style={styles.select} data-testid="key" aria-label="Musical key">
              {KEYS.map((k) => <option key={k} value={k}>{k}</option>)}
            </select>
          </div>
          <div style={{ flex: 1, minWidth: 120 }}>
            <div style={styles.label}>Name</div>
            <input value={name} maxLength={60} onChange={(e) => setName(e.target.value)} style={{ ...styles.select, width: "100%" }} data-testid="name" aria-label="Loop name" />
          </div>
        </div>
        <div style={{ ...styles.row, marginTop: 12 }}>
          <button style={styles.btn(PURPLE, "#fff")} onClick={autoGenerate} disabled={busy} data-testid="auto-generate" aria-label="Auto-generate beat and harmony">✦ Auto-beat / Auto-harmony</button>
          <button style={styles.btn(CYAN)} onClick={exportAll} disabled={busy} data-testid="export" aria-label="Export project as JSON and WAV">⭳ Export JSON + WAV</button>
          <button style={styles.ghost} onClick={saveAsPack} disabled={busy} data-testid="save-pack" aria-label="Save as sample pack">Save as Pack</button>
          <span style={styles.playhead} data-testid="playhead" aria-hidden="true">{playBeat >= 0 ? `beat ${playBeat + 1}/${GRID_BEATS}` : "—"}</span>
        </div>
      </div>

      {/* Track grid */}
      <div style={styles.panel} data-testid="track-grid" role="grid" aria-label="Beat grid, tracks by 16 beats" aria-rowcount={tracks.length} aria-colcount={GRID_BEATS}>
        {/* beat ruler (decorative) */}
        <div style={{ display: "flex", gap: 8, marginBottom: 8 }} aria-hidden="true">
          <div style={{ width: 160, flexShrink: 0 }} />
          <div style={styles.grid}>
            {Array.from({ length: GRID_BEATS }).map((_, b) => (
              <div key={b} style={{ textAlign: "center", fontSize: "0.62rem", color: b === playBeat ? CYAN : FAINT, fontFamily: "monospace" }}>{b % 4 === 0 ? `${b / 4 + 1}` : "·"}</div>
            ))}
          </div>
        </div>
        {tracks.map((t, ti) => (
          <div key={t.track_id} style={styles.trackRow} role="row" aria-rowindex={ti + 1} aria-label={`Track ${ti + 1}, ${t.instrument}`}>
            <div style={styles.trackHead(TRACK_COLORS[ti % TRACK_COLORS.length])} role="presentation">
              <select value={t.instrument} onChange={(e) => setTrackField(ti, "instrument", e.target.value)} style={{ ...styles.select, minHeight: 36 }} data-testid={`instrument-${ti}`} aria-label={`Track ${ti + 1} instrument`}>
                {INSTRUMENT_NAMES.map((n) => <option key={n} value={n}>{n}</option>)}
              </select>
              <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
                <button style={{ ...styles.ghost, minHeight: 32, padding: "4px 8px", fontSize: "0.7rem", borderColor: t.muted ? PURPLE : "rgba(255,255,255,0.18)", color: t.muted ? PURPLE : "#e8eaf0" }} onClick={() => setTrackField(ti, "muted", !t.muted)} data-testid={`mute-${ti}`} aria-pressed={t.muted} aria-label={`Track ${ti + 1} ${t.muted ? "unmute" : "mute"}`}>{t.muted ? "Muted" : "Mute"}</button>
                <input type="range" min={0} max={2} step={0.05} value={t.volume} onChange={(e) => setTrackField(ti, "volume", Number(e.target.value))} style={{ flex: 1 }} data-testid={`vol-${ti}`} aria-label={`Track ${ti + 1} volume`} aria-valuetext={`${Math.round(t.volume * 100)}%`} />
              </div>
              <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
                <span style={{ fontSize: "0.6rem", color: MUTE, width: 24 }} aria-hidden="true">PAN</span>
                <input type="range" min={-1} max={1} step={0.1} value={t.pan} onChange={(e) => setTrackField(ti, "pan", Number(e.target.value))} style={{ flex: 1 }} data-testid={`pan-${ti}`} aria-label={`Track ${ti + 1} pan`} aria-valuetext={t.pan === 0 ? "center" : t.pan < 0 ? `${Math.round(-t.pan * 100)}% left` : `${Math.round(t.pan * 100)}% right`} />
              </div>
            </div>
            <div style={styles.grid} role="presentation">
              {Array.from({ length: GRID_BEATS }).map((_, b) => {
                const on = cellOn(t, b);
                const isActive = ti === focus.row && b === focus.col;
                return (
                  <button key={b} type="button" data-testid={`cell-${ti}-${b}`} data-cell="1"
                    role="gridcell" aria-colindex={b + 1} aria-selected={on}
                    aria-label={`Track ${ti + 1} beat ${b + 1}, ${on ? "on" : "off"}`}
                    tabIndex={isActive ? 0 : -1}
                    ref={isActive ? activeCellRef : undefined}
                    onClick={() => { toggleCell(ti, b); setFocus({ row: ti, col: b }); }}
                    onKeyDown={onGridKeyDown}
                    style={{
                      ...styles.cell(on, TRACK_COLORS[ti % TRACK_COLORS.length], b % 4 === 0, reducedMotion),
                      outline: b === playBeat ? `2px solid ${PURPLE}` : "none",
                    }} />
                );
              })}
            </div>
          </div>
        ))}
      </div>

      {/* Composer challenge */}
      <div style={styles.panel} data-testid="composer-challenge">
        <div style={styles.row}>
          <button style={styles.btn(PURPLE, "#fff")} onClick={startChallenge} disabled={busy} data-testid="start-challenge" aria-label="Start composer challenge">Start Composer Challenge</button>
          <button style={styles.btn(CYAN)} onClick={submitChallenge} disabled={!challenge || busy} data-testid="submit-challenge" aria-label="Submit composition for scoring">Submit for Scoring</button>
          {challenge && <span style={styles.seedTag}>{challenge.challenge_id}</span>}
        </div>
        <div aria-live="polite" aria-atomic="true">
          {score && (
            <div style={{ marginTop: 16, display: "flex", gap: 24, alignItems: "flex-start", flexWrap: "wrap" }} data-testid="score-panel">
              <div role="img" aria-label={`Score ${score.score.toFixed(1)} out of 100`}>
                <div style={styles.scoreBig} data-testid="score-value">{score.score.toFixed(1)}</div>
                <div style={styles.label}>/ 100</div>
              </div>
              <div style={{ flex: 1, minWidth: 220, display: "flex", flexDirection: "column", gap: 10 }}>
                {["variety", "rhythm", "adherence"].map((k, i) => (
                  <div key={k} role="img" aria-label={`${k}: ${(score.breakdown[k] * 100).toFixed(0)} percent`}>
                    <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.72rem", color: "#9ca3af", marginBottom: 3 }} aria-hidden="true">
                      <span>{k}</span><span>{(score.breakdown[k] * 100).toFixed(0)}%</span>
                    </div>
                    <div style={styles.barTrack} aria-hidden="true"><div style={styles.bar(score.breakdown[k], TRACK_COLORS[i % TRACK_COLORS.length])} /></div>
                  </div>
                ))}
              </div>
              {score.extended && (
                <div style={{ flex: 1, minWidth: 220 }} data-testid="extended-metrics">
                  <div style={{ ...styles.label, marginBottom: 8 }}>Musicality {(score.extended.musicality * 100).toFixed(0)}%</div>
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "4px 16px" }}>
                    {Object.entries(score.extended.metrics).map(([k, v]) => (
                      <div key={k} style={{ display: "flex", justifyContent: "space-between", fontSize: "0.66rem", color: MUTE }}>
                        <span>{k.replace(/_/g, " ")}</span><span style={{ color: "#e8eaf0" }}>{(v * 100).toFixed(0)}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Status line: always in the DOM so the live region reliably announces. */}
      <div role="status" aria-live="polite" aria-atomic="true" data-testid="status"
        style={status
          ? { ...styles.panel, borderColor: statusBorder, fontSize: "0.82rem", color: statusColor }
          : srOnly}>
        {status}
      </div>
      {/* Transport-state announcement (not per-beat, to avoid SR spam). */}
      <div aria-live="polite" style={srOnly}>{playing ? `Playing, ${bpm} BPM` : ""}</div>

      {wavUrl && <audio controls src={wavUrl} style={{ width: "100%" }} data-testid="wav-preview" aria-label="Rendered loop preview" />}
    </div>
  );
}

function slug(s) { return ((s || "loop").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "loop").slice(0, 40); }
function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}
