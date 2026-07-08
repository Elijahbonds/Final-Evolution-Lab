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
 */
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { generateComposition } from "@/lib/musicTheory";
import {
  scheduleProject, renderProjectToWav, INSTRUMENT_NAMES,
} from "@/lib/audioEngine";

const API_BASE = process.env.REACT_APP_BACKEND_URL || "";
const API = `${API_BASE}/api`;

const CYAN = "#00D4FF";
const PURPLE = "#9933FF";

const KEYS = ["C", "Cm", "D", "Dm", "E", "Em", "F", "F#m", "G", "Gm", "A", "Am", "Bb", "Bm"];
const GRID_BEATS = 16; // 4 bars of 4/4
const STEP = 1;        // 1 beat per grid cell (beat-quantized placement)
const TRACK_COLORS = [CYAN, PURPLE, "#00E5A8", "#FFB800"];

const styles = {
  page: {
    background: "#08090b", color: "#e8eaf0", minHeight: "100vh",
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
    padding: "20px", boxSizing: "border-box",
  },
  header: { display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: 12, marginBottom: 16 },
  title: { fontSize: "1.5rem", fontWeight: 800, color: CYAN, margin: 0, letterSpacing: "0.02em" },
  sub: { fontSize: "0.75rem", color: "#6b7280", textTransform: "uppercase", letterSpacing: "0.15em" },
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
  label: { fontSize: "0.7rem", color: "#6b7280", textTransform: "uppercase", letterSpacing: "0.1em", marginBottom: 4 },
  trackRow: { display: "flex", alignItems: "stretch", gap: 8, marginBottom: 8 },
  trackHead: { width: 150, flexShrink: 0, display: "flex", flexDirection: "column", gap: 4, padding: 8, background: "#11151d", borderRadius: 8 },
  grid: { display: "grid", gridTemplateColumns: `repeat(${GRID_BEATS}, 1fr)`, gap: 3, flex: 1, minWidth: 0 },
  cell: (on, color, isBar) => ({
    minHeight: 44, borderRadius: 6, cursor: "pointer", touchAction: "manipulation",
    background: on ? color : "rgba(255,255,255,0.05)",
    border: isBar ? "1px solid rgba(255,255,255,0.16)" : "1px solid transparent",
    boxShadow: on ? `0 0 10px ${color}66` : "none", transition: "background 0.08s",
  }),
  playhead: { fontSize: "0.7rem", color: CYAN, fontFamily: "monospace" },
  seedTag: { fontFamily: "monospace", fontSize: "0.72rem", color: PURPLE, background: "rgba(153,51,255,0.12)", padding: "3px 8px", borderRadius: 6 },
  scoreBig: { fontSize: "2.4rem", fontWeight: 800, color: CYAN, lineHeight: 1 },
  bar: (v, color) => ({ height: 8, borderRadius: 4, background: color, width: `${Math.round(v * 100)}%`, minWidth: 2 }),
  barTrack: { height: 8, borderRadius: 4, background: "rgba(255,255,255,0.08)", flex: 1 },
};

function newTrack(i) {
  return {
    track_id: `trk_${Math.random().toString(36).slice(2, 10)}`,
    instrument: INSTRUMENT_NAMES[i % INSTRUMENT_NAMES.length],
    type: INSTRUMENT_NAMES[i % INSTRUMENT_NAMES.length] === "drum-kit" ? "sample" : "instrument",
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

  const [seed, setSeed] = useState(makeSeed);
  const [bpm, setBpm] = useState(120);
  const [musicKey, setMusicKey] = useState("Am");
  const [name, setName] = useState("Untitled Loop");
  const [tracks, setTracks] = useState(() => [newTrack(0), newTrack(1), newTrack(2), newTrack(3)]);
  const [metronome, setMetronome] = useState(false);
  const [looping, setLooping] = useState(true);
  const [playing, setPlaying] = useState(false);
  const [playBeat, setPlayBeat] = useState(-1);
  const [projectId, setProjectId] = useState(null);
  const [status, setStatus] = useState("");
  const [challenge, setChallenge] = useState(null);
  const [score, setScore] = useState(null);
  const [wavUrl, setWavUrl] = useState(null);

  const ctxRef = useRef(null);
  const rafRef = useRef(null);
  const startAtRef = useRef(0);

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

  const getCtx = () => {
    if (!ctxRef.current) ctxRef.current = new (window.AudioContext || window.webkitAudioContext)();
    if (ctxRef.current.state === "suspended") ctxRef.current.resume();
    return ctxRef.current;
  };

  const stop = useCallback(() => {
    setPlaying(false);
    setPlayBeat(-1);
    cancelAnimationFrame(rafRef.current);
    if (ctxRef.current) {
      try { ctxRef.current.close(); } catch (_e) { /* already closed */ }
      ctxRef.current = null;
    }
  }, []);

  const play = useCallback(() => {
    stop();
    const ctx = getCtx();
    const spb = 60 / bpm;
    const loopLen = GRID_BEATS * spb;
    const startAt = ctx.currentTime + 0.06;
    startAtRef.current = startAt;
    // Schedule one (or two, for seamless loop) passes.
    const passes = looping ? 4 : 1;
    for (let p = 0; p < passes; p++) scheduleProject(ctx, project, startAt + p * loopLen);
    setPlaying(true);
    const tick = () => {
      const elapsed = ctx.currentTime - startAt;
      if (elapsed < 0) { rafRef.current = requestAnimationFrame(tick); return; }
      const beat = Math.floor((elapsed / spb) % GRID_BEATS);
      setPlayBeat(beat);
      if (!looping && elapsed >= loopLen) { stop(); return; }
      rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
  }, [bpm, looping, project, stop]);

  useEffect(() => () => stop(), [stop]);

  const toggleCell = (ti, beat) => {
    setTracks((prev) => prev.map((t, i) => {
      if (i !== ti) return t;
      const exists = t.clips.find((c) => c.start === beat);
      const clips = exists
        ? t.clips.filter((c) => c.start !== beat)
        : [...t.clips, { start: beat, length: STEP }].sort((a, b) => a.start - b.start);
      return { ...t, clips };
    }));
    setScore(null);
  };

  const cellOn = (t, beat) => t.clips.some((c) => c.start === beat);

  const setTrackField = (ti, field, val) =>
    setTracks((prev) => prev.map((t, i) => {
      if (i !== ti) return t;
      const upd = { ...t, [field]: val };
      if (field === "instrument") upd.type = val === "drum-kit" ? "sample" : "instrument";
      return upd;
    }));

  // ── Auto-beat / auto-harmony (deterministic) ──
  const autoGenerate = () => {
    const comp = generateComposition(seed, musicKey, GRID_BEATS / 4);
    setTracks((prev) => prev.map((t) => {
      if (t.instrument === "drum-kit") {
        // Lay one drum clip per bar so the pattern plays across the grid.
        const clips = [];
        for (let b = 0; b < GRID_BEATS / 4; b++) clips.push({ start: b * 4, length: 4 });
        return { ...t, clips };
      }
      // Harmony tracks: place a chord clip at the start of each bar.
      const clips = comp.harmony.map((h) => ({ start: h.bar * 4, length: 4 }));
      return { ...t, clips };
    }));
    setStatus(`Auto-generated ${comp.genre} beat + harmony in ${comp.key}`);
    setScore(null);
  };

  // ── Persist + export (JSON via backend + WAV in-browser) ──
  const ensureProject = async () => {
    const body = { name, bpm, key: musicKey, seed, tracks: project.tracks, metadata: { composition } };
    const r = await fetch(`${API}/music/projects`, {
      method: "POST", headers: { "Content-Type": "application/json" }, credentials: "include",
      body: JSON.stringify(body),
    });
    if (!r.ok) throw new Error(`create failed: ${r.status}`);
    const data = await r.json();
    setProjectId(data.project_id);
    return data.project_id;
  };

  const exportAll = async () => {
    setStatus("Exporting…");
    try {
      // (a) project JSON via backend export endpoint
      let pid = projectId;
      try {
        pid = await ensureProject();
        const er = await fetch(`${API}/music/projects/${pid}/export`, { method: "POST", credentials: "include" });
        if (er.ok) {
          const exp = await er.json();
          downloadBlob(new Blob([JSON.stringify(exp, null, 2)], { type: "application/json" }), `${slug(name)}.json`);
        }
      } catch (e) {
        // Offline / RECORDING_LOCAL: export the local project as JSON directly.
        downloadBlob(new Blob([JSON.stringify({ export_version: "1.0-local", project_type: "music", project }, null, 2)], { type: "application/json" }), `${slug(name)}.json`);
      }
      // (b) in-browser WAV render via OfflineAudioContext
      const wav = await renderProjectToWav(project);
      const url = URL.createObjectURL(wav);
      setWavUrl(url);
      downloadBlob(wav, `${slug(name)}.wav`);
      setStatus("Exported JSON + WAV");
    } catch (e) {
      setStatus(`Export error: ${e.message}`);
    }
  };

  // ── Composer challenge ──
  const startChallenge = async () => {
    const constraints = { bpm, key: musicKey, instruments: ["instrument", "sample"], length_beats: 16, max_tracks: 4 };
    try {
      const r = await fetch(`${API}/music/composer-challenge/generate`, {
        method: "POST", headers: { "Content-Type": "application/json" }, credentials: "include",
        body: JSON.stringify({ seed, constraints }),
      });
      const data = r.ok ? await r.json() : { challenge_id: `chal_local_${seed}`, seed, constraints };
      setChallenge(data);
      setStatus(`Challenge: ${data.brief || "compose the best loop for this seed"}`);
    } catch (e) {
      setChallenge({ challenge_id: `chal_local_${seed}`, seed, constraints });
      setStatus("Challenge started (offline)");
    }
  };

  const submitChallenge = async () => {
    const constraints = challenge?.constraints || { bpm, key: musicKey, instruments: ["instrument", "sample"], length_beats: 16, max_tracks: 4 };
    try {
      const r = await fetch(`${API}/music/composer-challenge/score`, {
        method: "POST", headers: { "Content-Type": "application/json" }, credentials: "include",
        body: JSON.stringify({ seed, constraints, tracks: project.tracks, bpm, key: musicKey }),
      });
      if (!r.ok) throw new Error(`score ${r.status}`);
      setScore(await r.json());
      setStatus("Scored");
    } catch (e) {
      setStatus(`Scoring error: ${e.message}`);
    }
  };

  // ── Save as pack (Creator-Card-shaped) ──
  const saveAsPack = async () => {
    try {
      const pid = await ensureProject();
      const r = await fetch(`${API}/music/projects/${pid}/save-as-pack`, {
        method: "POST", headers: { "Content-Type": "application/json" }, credentials: "include",
        body: JSON.stringify({ card_id: "card_sampler_01" }),
      });
      if (!r.ok) throw new Error(`pack ${r.status}`);
      const data = await r.json();
      setStatus(`Saved pack "${data.pack.title}" · ${data.sample_count} samples`);
    } catch (e) {
      setStatus(`Save-as-pack error: ${e.message}`);
    }
  };

  return (
    <div style={styles.page} data-testid="music-mode">
      <div style={styles.header}>
        <div>
          <h1 style={styles.title}>MUSIC CREATION</h1>
          <div style={styles.sub}>WebAudio Loop Editor · Composer Challenge</div>
        </div>
        <div style={styles.row}>
          {recording && <span style={{ ...styles.seedTag, color: CYAN, background: "rgba(0,212,255,0.12)" }}>REC · LOCAL</span>}
          <span style={styles.seedTag} data-testid="seed-tag">seed: {seed}</span>
          <button style={styles.ghost} onClick={() => { setSeed(makeSeed()); setScore(null); }} data-testid="reseed">Reseed</button>
        </div>
      </div>

      {/* Transport + globals */}
      <div style={styles.panel}>
        <div style={styles.row}>
          {playing
            ? <button style={styles.btn(PURPLE, "#fff")} onClick={stop} data-testid="stop">■ Stop</button>
            : <button style={styles.btn(CYAN)} onClick={play} data-testid="play">▶ Play</button>}
          <button style={{ ...styles.ghost, borderColor: looping ? CYAN : "rgba(255,255,255,0.18)", color: looping ? CYAN : "#e8eaf0" }} onClick={() => setLooping((v) => !v)} data-testid="loop">Loop {looping ? "on" : "off"}</button>
          <button style={{ ...styles.ghost, borderColor: metronome ? CYAN : "rgba(255,255,255,0.18)", color: metronome ? CYAN : "#e8eaf0" }} onClick={() => setMetronome((v) => !v)} data-testid="metronome">Metronome {metronome ? "on" : "off"}</button>

          <div>
            <div style={styles.label}>BPM</div>
            <input type="number" min={20} max={300} value={bpm} onChange={(e) => setBpm(Math.max(20, Math.min(300, Number(e.target.value) || 120)))} style={{ ...styles.select, width: 78 }} data-testid="bpm" />
          </div>
          <div>
            <div style={styles.label}>Key</div>
            <select value={musicKey} onChange={(e) => { setMusicKey(e.target.value); setScore(null); }} style={styles.select} data-testid="key">
              {KEYS.map((k) => <option key={k} value={k}>{k}</option>)}
            </select>
          </div>
          <div style={{ flex: 1, minWidth: 120 }}>
            <div style={styles.label}>Name</div>
            <input value={name} onChange={(e) => setName(e.target.value)} style={{ ...styles.select, width: "100%" }} data-testid="name" />
          </div>
        </div>
        <div style={{ ...styles.row, marginTop: 12 }}>
          <button style={styles.btn(PURPLE, "#fff")} onClick={autoGenerate} data-testid="auto-generate">✦ Auto-beat / Auto-harmony</button>
          <button style={styles.btn(CYAN)} onClick={exportAll} data-testid="export">⭳ Export JSON + WAV</button>
          <button style={styles.ghost} onClick={saveAsPack} data-testid="save-pack">Save as Pack</button>
          <span style={styles.playhead} data-testid="playhead">{playBeat >= 0 ? `beat ${playBeat + 1}/${GRID_BEATS}` : "—"}</span>
        </div>
      </div>

      {/* Track grid */}
      <div style={styles.panel} data-testid="track-grid">
        {/* beat ruler */}
        <div style={{ display: "flex", gap: 8, marginBottom: 8 }}>
          <div style={{ width: 150, flexShrink: 0 }} />
          <div style={styles.grid}>
            {Array.from({ length: GRID_BEATS }).map((_, b) => (
              <div key={b} style={{ textAlign: "center", fontSize: "0.62rem", color: b === playBeat ? CYAN : "#4b5563", fontFamily: "monospace" }}>{b % 4 === 0 ? `${b / 4 + 1}` : "·"}</div>
            ))}
          </div>
        </div>
        {tracks.map((t, ti) => (
          <div key={t.track_id} style={styles.trackRow}>
            <div style={styles.trackHead}>
              <select value={t.instrument} onChange={(e) => setTrackField(ti, "instrument", e.target.value)} style={{ ...styles.select, minHeight: 36 }} data-testid={`instrument-${ti}`}>
                {INSTRUMENT_NAMES.map((n) => <option key={n} value={n}>{n}</option>)}
              </select>
              <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
                <button style={{ ...styles.ghost, minHeight: 32, padding: "4px 8px", fontSize: "0.7rem", borderColor: t.muted ? PURPLE : "rgba(255,255,255,0.18)", color: t.muted ? PURPLE : "#e8eaf0" }} onClick={() => setTrackField(ti, "muted", !t.muted)} data-testid={`mute-${ti}`}>{t.muted ? "Muted" : "Mute"}</button>
                <input type="range" min={0} max={2} step={0.05} value={t.volume} onChange={(e) => setTrackField(ti, "volume", Number(e.target.value))} style={{ flex: 1 }} data-testid={`vol-${ti}`} aria-label={`volume ${ti}`} />
              </div>
            </div>
            <div style={styles.grid}>
              {Array.from({ length: GRID_BEATS }).map((_, b) => (
                <div key={b} data-testid={`cell-${ti}-${b}`}
                  onClick={() => toggleCell(ti, b)}
                  style={{
                    ...styles.cell(cellOn(t, b), TRACK_COLORS[ti % TRACK_COLORS.length], b % 4 === 0),
                    outline: b === playBeat ? `2px solid ${CYAN}` : "none",
                  }} />
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* Composer challenge */}
      <div style={styles.panel} data-testid="composer-challenge">
        <div style={styles.row}>
          <button style={styles.btn(PURPLE, "#fff")} onClick={startChallenge} data-testid="start-challenge">Start Composer Challenge</button>
          <button style={styles.btn(CYAN)} onClick={submitChallenge} disabled={!challenge} data-testid="submit-challenge">Submit for Scoring</button>
          {challenge && <span style={styles.seedTag}>{challenge.challenge_id}</span>}
        </div>
        {score && (
          <div style={{ marginTop: 16, display: "flex", gap: 24, alignItems: "center", flexWrap: "wrap" }} data-testid="score-panel">
            <div>
              <div style={styles.scoreBig} data-testid="score-value">{score.score.toFixed(1)}</div>
              <div style={styles.label}>/ 100</div>
            </div>
            <div style={{ flex: 1, minWidth: 220, display: "flex", flexDirection: "column", gap: 10 }}>
              {["variety", "rhythm", "adherence"].map((k, i) => (
                <div key={k}>
                  <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.72rem", color: "#9ca3af", marginBottom: 3 }}>
                    <span>{k}</span><span>{(score.breakdown[k] * 100).toFixed(0)}%</span>
                  </div>
                  <div style={styles.barTrack}><div style={styles.bar(score.breakdown[k], TRACK_COLORS[i % TRACK_COLORS.length])} /></div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {status && <div style={{ ...styles.panel, borderColor: "rgba(153,51,255,0.25)", fontSize: "0.82rem", color: "#c4b5fd" }} data-testid="status">{status}</div>}
      {wavUrl && <audio controls src={wavUrl} style={{ width: "100%" }} data-testid="wav-preview" />}
    </div>
  );
}

function slug(s) { return (s || "loop").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "loop"; }
function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}
