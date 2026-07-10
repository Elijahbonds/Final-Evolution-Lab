/**
 * DanceMode — Nexus Dance Game Mode (rhythm performance + choreography editor)
 *
 * Route: /nexus/dance   (add ?recording=1 for a locally-authoritative solo run)
 *
 * Three views:
 *   1. PERFORMANCE  — the demo hero. Beat prompts scroll to a hit line synced
 *      to a deterministic beatmap (seed+bpm). Player hits 4-lane timing windows
 *      (keyboard D/F/J/K + touch). Combo counter, judge overlay, slow-mo on a
 *      big combo. Score submitted to the server for authoritative scoring.
 *   2. CHOREOGRAPHY — beat-aligned timeline of animation clips (from a bundled
 *      CC0 sample set), adjustable clip speed + transitions.
 *   3. PLAYBACK     — plays the assembled choreography against the beat with a
 *      stylized 2D avatar. (Full 3D rig is intentionally out of scope for the
 *      web demo — flagged in-UI.)
 *
 * The beatmap is FETCHED from GET /api/dance/projects/{id}/beatmap so the notes
 * shown are byte-identical to what the server scores against (the server uses a
 * Mersenne-Twister PRNG that we don't reimplement in JS).
 */
import React, { useEffect, useRef, useState, useCallback } from 'react';
import './danceMode.css';
import DanceAvatar from './DanceAvatar';

// Honour the user's reduced-motion preference for decorative effects (slow-mo,
// avatar breathing). Guarded for SSR / older browsers.
const prefersReducedMotion = () =>
  typeof window !== 'undefined' && window.matchMedia
    ? window.matchMedia('(prefers-reduced-motion: reduce)').matches
    : false;

const API_BASE = process.env.REACT_APP_BACKEND_URL || '';
const API = `${API_BASE}/api`;

const LANE_KEYS = ['d', 'f', 'j', 'k'];
const LANE_LABELS = ['D', 'F', 'J', 'K'];
const LANES = 4;
const SCROLL_MS = 1800;        // time a note takes to travel top -> hit line
const HIT_WINDOW_MS = 90;      // client-side visual window (server is authoritative)
const PERFECT_MS = 40;
const STAGE_H = 420;
const HITLINE_BOTTOM = 64;     // px from bottom (matches CSS)

// Bundled CC0 sample clips (placeholders — real mocap/Meshy clips slot in later).
const SAMPLE_CLIPS = [
  { id: 'clip_idle', name: 'Idle Sway', duration: 2.0 },
  { id: 'clip_step', name: 'Two-Step', duration: 1.5 },
  { id: 'clip_spin', name: 'Spin', duration: 1.0 },
  { id: 'clip_wave', name: 'Wave', duration: 2.5 },
  { id: 'clip_jump', name: 'Jump', duration: 0.8 },
  { id: 'clip_pose', name: 'Freeze Pose', duration: 1.2 },
];

function useQuery() {
  return new URLSearchParams(window.location.search);
}

export default function DanceMode({ onExit }) {
  const query = useQuery();
  const recordingMode = query.get('recording') === '1';

  const [view, setView] = useState('performance');
  const [project, setProject] = useState(null);
  const [status, setStatus] = useState('Creating dance project…');
  const [bpm, setBpm] = useState(128);
  const [difficulty, setDifficulty] = useState('normal');
  const [seedInput, setSeedInput] = useState('');

  // Create (or recreate) a dance project on the backend.
  const createProject = useCallback(async (seed) => {
    setStatus('Creating dance project…');
    try {
      const body = {
        name: 'Nexus Dance Demo',
        skeleton: 'humanoid_v1',
        bpm,
        animations: SAMPLE_CLIPS.map((c) => ({ name: c.name, duration: c.duration, source: 'library' })),
        timeline: { entries: [] },
      };
      if (seed !== undefined && seed !== null && `${seed}`.length) body.seed = Number(seed);
      const res = await fetch(`${API}/dance/projects`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
      });
      if (!res.ok) throw new Error(`create failed ${res.status}`);
      const proj = await res.json();
      setProject(proj);
      setSeedInput(`${proj.seed}`);
      setStatus('');
    } catch (e) {
      setStatus(`Backend unavailable (${e.message}). Start it: cd backend && MOCK_DB=1 uvicorn server:app --port 8000`);
    }
  }, [bpm]);

  useEffect(() => { createProject(); /* eslint-disable-next-line */ }, []);

  return (
    <div className="dm-root">
      <div className="dm-header">
        <div>
          <h1 className="dm-title">Nexus Dance Mode</h1>
          <div className="dm-sub">
            Rhythm performance + choreography · {recordingMode ? 'RECORDING_LOCAL (solo, seed-visible)' : 'live scoring'}
            {project && <> · <span className="dm-seedchip">seed {project.seed}</span></>}
          </div>
        </div>
        <div className="dm-tabs">
          <div className={`dm-tab ${view === 'performance' ? 'active' : ''}`} onClick={() => setView('performance')}>Performance</div>
          <div className={`dm-tab ${view === 'choreography' ? 'active' : ''}`} onClick={() => setView('choreography')}>Choreography</div>
          <div className={`dm-tab ${view === 'playback' ? 'active' : ''}`} onClick={() => setView('playback')}>Playback</div>
          {onExit && <div className="dm-tab" onClick={onExit}>Exit</div>}
        </div>
      </div>

      {status && <div className="dm-panel dm-flag">{status}</div>}

      {project && view === 'performance' && (
        <PerformanceView project={project} bpm={bpm} setBpm={setBpm}
          difficulty={difficulty} setDifficulty={setDifficulty}
          seedInput={seedInput} setSeedInput={setSeedInput}
          onReseed={(s) => createProject(s)} recordingMode={recordingMode} />
      )}
      {project && view === 'choreography' && (
        <ChoreographyView project={project} setProject={setProject} />
      )}
      {project && view === 'playback' && (
        <PlaybackView project={project} />
      )}
    </div>
  );
}

/* ────────────────────────────── PERFORMANCE ─────────────────────────────── */

function PerformanceView({ project, bpm, setBpm, difficulty, setDifficulty, seedInput, setSeedInput, onReseed, recordingMode }) {
  const [beatmap, setBeatmap] = useState(null);
  const [running, setRunning] = useState(false);
  const [result, setResult] = useState(null);
  const [combo, setCombo] = useState(0);
  const [score, setScore] = useState(0);
  const [judge, setJudge] = useState(null);        // {name, key}
  const [slowmo, setSlowmo] = useState(false);
  const [keysDown, setKeysDown] = useState([false, false, false, false]);
  const [comboPulse, setComboPulse] = useState(0);
  const [perfBeat, setPerfBeat] = useState(0);   // beat clock for the reactive avatar
  const [progress, setProgress] = useState(0);    // 0..1 run progress for the bar

  const stageRef = useRef(null);
  const rafRef = useRef(null);
  const startRef = useRef(0);
  const hitsRef = useRef([]);          // {time_ms, lane}
  const noteStateRef = useRef([]);     // per-event {judged}
  const notesLayerRef = useRef(null);

  const fetchBeatmap = useCallback(async () => {
    const url = `${API}/dance/projects/${project.project_id}/beatmap?difficulty=${difficulty}&beats=32&subdivision=2`;
    const res = await fetch(url);
    const bm = await res.json();
    setBeatmap(bm);
    return bm;
  }, [project.project_id, difficulty]);

  useEffect(() => { fetchBeatmap(); }, [fetchBeatmap]);

  const registerHit = useCallback((lane) => {
    if (!running || !beatmap) return;
    const now = performance.now() - startRef.current;
    hitsRef.current.push({ time_ms: now, lane });
    // Client-side visual judgment: nearest unjudged same-lane note within window.
    let best = -1, bestErr = Infinity;
    beatmap.events.forEach((ev, i) => {
      if (ev.lane !== lane || noteStateRef.current[i]?.judged) return;
      const err = Math.abs(ev.time_ms - now);
      if (err < bestErr && err <= HIT_WINDOW_MS) { bestErr = err; best = i; }
    });
    let name = 'miss';
    if (best >= 0) {
      noteStateRef.current[best] = { judged: true };
      name = bestErr <= PERFECT_MS ? 'perfect' : 'good';
      setScore((s) => s + (name === 'perfect' ? 100 : 50));
      setCombo((c) => {
        const nc = c + 1;
        // Cinematic slow-mo on every 10th combo — suppressed under reduced-motion.
        if (!prefersReducedMotion() && nc > 0 && nc % 10 === 0) {
          setSlowmo(true); setTimeout(() => setSlowmo(false), 1100);
        }
        return nc;
      });
      setComboPulse((p) => p + 1);
    } else {
      setCombo(0);
    }
    setJudge({ name, key: Math.random() });
  }, [running, beatmap]);

  // Keyboard input
  useEffect(() => {
    const down = (e) => {
      if (e.repeat) return;                    // ignore OS key auto-repeat
      const lane = LANE_KEYS.indexOf(e.key.toLowerCase());
      if (lane < 0) return;
      e.preventDefault();
      setKeysDown((k) => { const n = [...k]; n[lane] = true; return n; });
      registerHit(lane);
    };
    const up = (e) => {
      const lane = LANE_KEYS.indexOf(e.key.toLowerCase());
      if (lane < 0) return;
      setKeysDown((k) => { const n = [...k]; n[lane] = false; return n; });
    };
    window.addEventListener('keydown', down);
    window.addEventListener('keyup', up);
    return () => { window.removeEventListener('keydown', down); window.removeEventListener('keyup', up); };
  }, [registerHit]);

  const submitRun = useCallback(async () => {
    const endpoint = recordingMode ? 'record' : 'score';
    const body = {
      hits: hitsRef.current,
      latency_ms: 0,
      difficulty,
      beats: 32,
      subdivision: 2,
    };
    if (recordingMode) body.recording = true;
    try {
      const res = await fetch(`${API}/dance/projects/${project.project_id}/${endpoint}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
      });
      const data = await res.json();
      setResult(data.result);
    } catch (e) {
      setResult({ error: e.message });
    }
  }, [project.project_id, difficulty, recordingMode]);

  // Animation loop: render scrolling notes + auto-detect end.
  const tick = useCallback(() => {
    const bm = beatmap;
    if (!bm || !notesLayerRef.current) { rafRef.current = requestAnimationFrame(tick); return; }
    const elapsed = performance.now() - startRef.current;
    const layer = notesLayerRef.current;
    // Beat clock + run progress for the reactive avatar and the progress bar.
    const beatMs = 60000 / (bm.bpm || 128);
    setPerfBeat(elapsed > 0 ? elapsed / beatMs : 0);
    setProgress(Math.max(0, Math.min(1, elapsed / (bm.duration_ms || 1))));
    // Position notes that are on-screen.
    const travel = STAGE_H - HITLINE_BOTTOM; // px from top to hit line
    bm.events.forEach((ev, i) => {
      let el = layer.querySelector(`[data-note="${i}"]`);
      const appearAt = ev.time_ms - SCROLL_MS;
      const gonAt = ev.time_ms + 300;
      const onScreen = elapsed >= appearAt && elapsed <= gonAt && !noteStateRef.current[i]?.judged;
      if (onScreen) {
        if (!el) {
          el = document.createElement('div');
          el.className = `dm-note ${ev.lane % 2 ? 'l1' : ''} ${ev.kind === 'hold' ? 'hold' : ''}`;
          el.setAttribute('data-note', i);
          el.setAttribute('data-lane', ev.lane);   // colorblind-safe glyph hook
          const laneEl = layer.children[ev.lane];
          if (laneEl) laneEl.appendChild(el);
        }
        const progress = (elapsed - appearAt) / SCROLL_MS; // 0..1
        el.style.top = `${Math.min(progress, 1.05) * travel - 11}px`;
      } else if (el) {
        el.remove();
        // Auto-miss notes that scrolled past without a hit.
        if (elapsed > gonAt && !noteStateRef.current[i]?.judged) {
          noteStateRef.current[i] = { judged: true, missed: true };
        }
      }
    });
    // End of run.
    if (elapsed > bm.duration_ms + SCROLL_MS) {
      setRunning(false);
      cancelAnimationFrame(rafRef.current);
      submitRun();
      return;
    }
    rafRef.current = requestAnimationFrame(tick);
  }, [beatmap, submitRun]);

  const start = useCallback(async () => {
    const bm = beatmap || await fetchBeatmap();
    if (!bm) return;
    // reset
    if (notesLayerRef.current) {
      notesLayerRef.current.querySelectorAll('.dm-note').forEach((n) => n.remove());
    }
    hitsRef.current = [];
    noteStateRef.current = bm.events.map(() => ({ judged: false }));
    setResult(null); setCombo(0); setScore(0); setJudge(null); setSlowmo(false);
    setPerfBeat(0); setProgress(0);
    setRunning(true);
    startRef.current = performance.now() + 1500; // 1.5s lead-in
    cancelAnimationFrame(rafRef.current);
    rafRef.current = requestAnimationFrame(tick);
  }, [beatmap, fetchBeatmap, tick]);

  useEffect(() => () => cancelAnimationFrame(rafRef.current), []);

  return (
    <div>
      <div className="dm-panel" style={{ marginBottom: 14 }}>
        <div className="dm-row">
          <div className="dm-field">
            <label>BPM</label>
            <input className="dm-input" type="number" min="20" max="300" value={bpm}
              onChange={(e) => setBpm(Number(e.target.value))} disabled={running} style={{ width: 90 }} />
          </div>
          <div className="dm-field">
            <label>Difficulty</label>
            <select className="dm-select" value={difficulty} onChange={(e) => setDifficulty(e.target.value)} disabled={running}>
              <option value="easy">Easy</option>
              <option value="normal">Normal</option>
              <option value="hard">Hard</option>
              <option value="expert">Expert</option>
            </select>
          </div>
          <div className="dm-field">
            <label>Seed</label>
            <div className="dm-row">
              <input className="dm-input" value={seedInput} onChange={(e) => setSeedInput(e.target.value)}
                disabled={running} style={{ width: 150 }} />
              <button className="dm-btn ghost" onClick={() => onReseed(seedInput)} disabled={running}>Reseed</button>
            </div>
          </div>
          <div style={{ flex: 1 }} />
          <button className="dm-btn" onClick={start} disabled={running || !beatmap}>
            {running ? 'Performing…' : recordingMode ? '● Record run' : '▶ Start run'}
          </button>
        </div>
        <div className="dm-muted" style={{ marginTop: 8 }}>
          Hit the notes on the line with <b>D F J K</b> (or tap the pads). Beatmap is deterministic from the seed —
          {beatmap ? ` ${beatmap.note_count} notes` : ' loading…'}. Scoring is server-authoritative.
        </div>
      </div>

      <div ref={stageRef} className={`dm-stage ${slowmo ? 'slowmo' : ''}`}>
        <div className="dm-scorebar" aria-live="polite" aria-atomic="true">
          <div className="s">{score.toLocaleString()}</div><div className="l">SCORE</div>
        </div>
        <div className={`dm-combo ${comboPulse ? 'pulse' : ''}`} key={comboPulse}
          aria-live="polite" aria-atomic="true">
          <div className="n">{combo}</div><div className="l">COMBO</div>
        </div>

        {/* Beat-reactive silhouette — brightens with combo, sparks on lane hits. */}
        <div className="dm-stage-avatar" aria-hidden="true">
          <DanceAvatar clip={combo > 20 ? 'Two-Step' : 'Idle Sway'}
            beat={perfBeat} playing={running && !prefersReducedMotion()}
            reactive={{ lanes: keysDown, combo }} size={132} />
        </div>

        <div ref={notesLayerRef} className="dm-lanes">
          {Array.from({ length: LANES }).map((_, i) => (
            <div key={i} className={`dm-lane ${keysDown[i] ? 'flash' : ''}`} />
          ))}
        </div>
        <div className="dm-hitline" />

        {/* Run progress bar. */}
        <div className="dm-progress" aria-hidden="true"><div className="fill" style={{ width: `${(progress * 100).toFixed(1)}%` }} /></div>

        {/* Decorative animated judgment (assertive text mirror below for SR users). */}
        {judge && <div key={judge.key} className={`dm-judge ${judge.name}`} aria-hidden="true">{judge.name.toUpperCase()}</div>}
        <div className="dm-sr-only" role="status" aria-live="assertive">{judge ? judge.name : ''}</div>

        <div className="dm-keys">
          {LANE_LABELS.map((lbl, i) => (
            <div key={i} className={`dm-key ${keysDown[i] ? 'down' : ''}`}
              role="button" tabIndex={0} aria-label={`Lane ${i + 1}, key ${lbl}`} data-lane={i}
              onPointerDown={(e) => { e.preventDefault(); setKeysDown((k) => { const n = [...k]; n[i] = true; return n; }); registerHit(i); }}
              onPointerUp={() => setKeysDown((k) => { const n = [...k]; n[i] = false; return n; })}
              onPointerLeave={() => setKeysDown((k) => { const n = [...k]; n[i] = false; return n; })}
            >{lbl}</div>
          ))}
        </div>
      </div>

      {result && !result.error && (
        <div className="dm-panel dm-results" style={{ marginTop: 14 }}>
          <div className="dm-grade">{result.grade}</div>
          <div style={{ fontSize: '1.1rem', fontWeight: 700 }}>
            {result.score.toLocaleString()} pts · {(result.accuracy * 100).toFixed(1)}% accuracy
            {result.big_combo && <span style={{ color: 'var(--dm-cyan)' }}> · BIG COMBO ✦</span>}
          </div>
          <div className="dm-stats">
            <div className="dm-stat"><div className="v" style={{ color: 'var(--dm-perfect)' }}>{result.tallies.perfect}</div><div className="k">Perfect</div></div>
            <div className="dm-stat"><div className="v" style={{ color: 'var(--dm-good)' }}>{result.tallies.good}</div><div className="k">Good</div></div>
            <div className="dm-stat"><div className="v" style={{ color: 'var(--dm-miss)' }}>{result.tallies.miss}</div><div className="k">Miss</div></div>
            <div className="dm-stat"><div className="v">{result.max_combo}</div><div className="k">Max Combo</div></div>
          </div>
          <div className="dm-muted" style={{ marginTop: 10 }}>
            {recordingMode ? 'Recorded to replay store — export via /api/replays/' + project.project_id + '/export' : 'Server-scored (deterministic). Re-run with the same seed for the same map.'}
          </div>
        </div>
      )}
      {result && result.error && <div className="dm-panel dm-flag" style={{ marginTop: 14 }}>Score submit failed: {result.error}</div>}
    </div>
  );
}

/* ───────────────────────────── CHOREOGRAPHY ─────────────────────────────── */

const BEATS_VISIBLE = 32;
const PX_PER_BEAT = 34;

function ChoreographyView({ project, setProject }) {
  const [entries, setEntries] = useState(project.timeline?.entries || []);
  const [selected, setSelected] = useState(null);
  const [saveMsg, setSaveMsg] = useState('');

  const addClip = (clip) => {
    // Place at first free beat after the last clip.
    const lastEnd = entries.reduce((m, e) => Math.max(m, (e.start_beat || 0) + beatsForClip(e)), 0);
    setEntries([...entries, { animation: clip.name, clip_id: clip.id, start_beat: lastEnd, speed: 1.0, transition: 'cut' }]);
  };

  const beatsForClip = (e) => {
    const clip = SAMPLE_CLIPS.find((c) => c.name === e.animation) || { duration: 2 };
    // seconds -> beats at project bpm, adjusted by speed
    return Math.max(1, Math.round((clip.duration / (60 / project.bpm)) / (e.speed || 1)));
  };

  const updateSel = (patch) => {
    setEntries((es) => es.map((e, i) => (i === selected ? { ...e, ...patch } : e)));
  };
  const removeSel = () => { setEntries((es) => es.filter((_, i) => i !== selected)); setSelected(null); };

  const save = async (asPack) => {
    setSaveMsg('Saving…');
    try {
      const res = await fetch(`${API}/dance/projects/${project.project_id}/choreography`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ timeline: { entries }, save_as_pack: !!asPack }),
      });
      const data = await res.json();
      setProject({ ...project, timeline: data.timeline });
      setSaveMsg(asPack ? 'Saved + choreography pack flagged (card_choreo_01).' : 'Choreography saved.');
    } catch (e) { setSaveMsg(`Save failed: ${e.message}`); }
  };

  return (
    <div>
      <div className="dm-flag">
        Timeline uses bundled CC0 <b>placeholder</b> clips. Real mocap / Meshy / DeepMotion clips slot into the same
        entries (animation + start_beat + speed + transition) once retargeted to <code>humanoid_v1</code>.
      </div>
      <div className="dm-grid2">
        <div className="dm-panel">
          <div className="dm-muted" style={{ marginBottom: 8 }}>Clip library (CC0 samples)</div>
          <div className="dm-clip-lib">
            {SAMPLE_CLIPS.map((c) => (
              <div key={c.id} className="dm-clip-card" onClick={() => addClip(c)}>
                <div>{c.name}</div><div className="d">{c.duration}s · + add</div>
              </div>
            ))}
          </div>
        </div>
        <div className="dm-panel">
          <div className="dm-muted" style={{ marginBottom: 8 }}>Selected clip</div>
          {selected == null ? <div className="dm-muted">Click a clip on the timeline to edit its speed / transition.</div> : (
            <div>
              <div style={{ fontWeight: 800, marginBottom: 8 }}>{entries[selected]?.animation}</div>
              <div className="dm-row">
                <div className="dm-field">
                  <label>Speed ×{(entries[selected]?.speed || 1).toFixed(2)}</label>
                  <input type="range" min="0.5" max="2" step="0.05" value={entries[selected]?.speed || 1}
                    onChange={(e) => updateSel({ speed: Number(e.target.value) })} />
                </div>
                <div className="dm-field">
                  <label>Transition in</label>
                  <select className="dm-select" value={entries[selected]?.transition || 'cut'}
                    onChange={(e) => updateSel({ transition: e.target.value })}>
                    <option value="cut">Cut</option>
                    <option value="crossfade">Crossfade</option>
                    <option value="ease">Ease</option>
                  </select>
                </div>
                <div className="dm-field">
                  <label>Start beat</label>
                  <input className="dm-input" type="number" min="0" style={{ width: 80 }}
                    value={entries[selected]?.start_beat || 0}
                    onChange={(e) => updateSel({ start_beat: Number(e.target.value) })} />
                </div>
              </div>
              <button className="dm-btn ghost" style={{ marginTop: 10 }} onClick={removeSel}>Remove clip</button>
            </div>
          )}
        </div>
      </div>

      <div className="dm-panel" style={{ marginTop: 14 }}>
        <div className="dm-muted" style={{ marginBottom: 8 }}>Timeline — {project.bpm} BPM · beats aligned to the grid</div>
        <div className="dm-timeline">
          <div className="dm-track" style={{ width: BEATS_VISIBLE * PX_PER_BEAT }}>
            <div className="dm-beatgrid">
              {Array.from({ length: BEATS_VISIBLE + 1 }).map((_, b) => (
                <div key={b} className={`dm-beatline ${b % 4 === 0 ? 'bar' : ''}`} style={{ left: b * PX_PER_BEAT }} />
              ))}
            </div>
            {entries.map((e, i) => (
              <div key={i} className={`dm-clip ${selected === i ? 'sel' : ''}`}
                style={{ left: (e.start_beat || 0) * PX_PER_BEAT, width: beatsForClip(e) * PX_PER_BEAT - 4 }}
                onClick={() => setSelected(i)}>
                {e.transition && e.transition !== 'cut' && <div className="tr" />}
                {e.animation}{e.speed && e.speed !== 1 ? ` ×${e.speed}` : ''}
              </div>
            ))}
          </div>
        </div>
        <div className="dm-row" style={{ marginTop: 12 }}>
          <button className="dm-btn" onClick={() => save(false)}>Save choreography</button>
          <button className="dm-btn ghost" onClick={() => save(true)}>Save as pack (Creator Card)</button>
          {saveMsg && <span className="dm-muted">{saveMsg}</span>}
        </div>
      </div>
    </div>
  );
}

/* ────────────────────────────── PLAYBACK ────────────────────────────────── */

function PlaybackView({ project }) {
  const entries = project.timeline?.entries || [];
  const [playing, setPlaying] = useState(false);
  const [beat, setBeat] = useState(0);
  const [activeClip, setActiveClip] = useState(null);
  const rafRef = useRef(null);
  const startRef = useRef(0);
  const beatMs = 60000 / project.bpm;

  const beatsForClip = (e) => {
    const clip = SAMPLE_CLIPS.find((c) => c.name === e.animation) || { duration: 2 };
    return Math.max(1, Math.round((clip.duration / (60 / project.bpm)) / (e.speed || 1)));
  };
  const totalBeats = entries.reduce((m, e) => Math.max(m, (e.start_beat || 0) + beatsForClip(e)), BEATS_VISIBLE);

  const loop = useCallback(() => {
    const elapsed = performance.now() - startRef.current;
    const b = elapsed / beatMs;
    setBeat(b);
    const active = entries.find((e) => b >= (e.start_beat || 0) && b < (e.start_beat || 0) + beatsForClip(e));
    setActiveClip(active ? active.animation : null);
    if (b >= totalBeats) { setPlaying(false); return; }
    rafRef.current = requestAnimationFrame(loop);
  }, [entries, beatMs, totalBeats]);

  const play = () => {
    if (!entries.length) return;
    setPlaying(true); startRef.current = performance.now();
    cancelAnimationFrame(rafRef.current); rafRef.current = requestAnimationFrame(loop);
  };
  useEffect(() => () => cancelAnimationFrame(rafRef.current), []);

  const rm = prefersReducedMotion();

  return (
    <div>
      <div className="dm-flag">
        Playback is a <b>stylized 2D visualization</b> (a beat-driven 2D dancer + clip highlight), not a full 3D rig —
        that's an intentional web-demo scope limit. The timeline + beat sync are real; a 3D rig reads the same timeline entries.
      </div>
      <div className="dm-panel" style={{ textAlign: 'center', padding: 30 }}>
        <DanceAvatar clip={activeClip} beat={beat} playing={playing && !rm} size={200} />
        <div style={{ marginTop: 16, fontWeight: 800, fontSize: '1.2rem' }}>
          {activeClip || (playing ? '…' : 'Ready')}
        </div>
        <div className="dm-muted">Beat {beat.toFixed(1)} / {totalBeats} · {project.bpm} BPM</div>
        <div style={{ marginTop: 14 }}>
          <button className="dm-btn" onClick={play} disabled={playing || !entries.length}>
            {playing ? 'Playing…' : '▶ Play choreography'}
          </button>
        </div>
        {!entries.length && <div className="dm-muted" style={{ marginTop: 10 }}>No clips yet — add some in the Choreography tab.</div>}
      </div>

      <div className="dm-panel" style={{ marginTop: 14 }}>
        <div className="dm-muted" style={{ marginBottom: 8 }}>Timeline (playhead)</div>
        <div className="dm-timeline">
          <div className="dm-track" style={{ width: Math.max(BEATS_VISIBLE, totalBeats) * PX_PER_BEAT }}>
            <div className="dm-beatgrid">
              {Array.from({ length: Math.max(BEATS_VISIBLE, totalBeats) + 1 }).map((_, b) => (
                <div key={b} className={`dm-beatline ${b % 4 === 0 ? 'bar' : ''}`} style={{ left: b * PX_PER_BEAT }} />
              ))}
            </div>
            {entries.map((e, i) => (
              <div key={i} className="dm-clip" style={{ left: (e.start_beat || 0) * PX_PER_BEAT, width: beatsForClip(e) * PX_PER_BEAT - 4 }}>
                {e.animation}
              </div>
            ))}
            {playing && <div className="dm-playhead" style={{ left: beat * PX_PER_BEAT }} />}
          </div>
        </div>
      </div>
    </div>
  );
}
