import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { saveRun, listRuns, updateRun, deleteRun, bestRun } from '@/lib/irlRuns';

/**
 * IRL Dunk — H2H & Mirror Triumph (v1, local-only).
 * Route: /irl/dunk
 *
 * - Submit a real-life dunk run (camera capture or file). Video stays ON
 *   THIS DEVICE — no upload path exists in v1.
 * - Mirror Triumph: latest run vs your personal best, side by side.
 * - Couch H2H: any two runs, judged live by the people in the room.
 * - No money anywhere. Friendly competition only. Scores are self-reported
 *   and labeled PROVISIONAL until a review pipeline verifies them.
 */
export default function IRLDunkPage() {
  const navigate = useNavigate();
  const fileRef = useRef(null);
  const [runs, setRuns] = useState([]);
  const [selfScore, setSelfScore] = useState(30);
  const [notes, setNotes] = useState('');
  const [mirror, setMirror] = useState(null);   // { current, best }
  const [duel, setDuel] = useState(null);       // { a, b, winnerId? }
  const [urls] = useState(() => new Map());     // runId -> objectURL cache

  const refresh = useCallback(async () => {
    try { setRuns(await listRuns()); } catch { setRuns([]); }
  }, []);
  useEffect(() => { refresh(); }, [refresh]);
  useEffect(() => () => { urls.forEach((u) => URL.revokeObjectURL(u)); }, [urls]);

  const videoUrl = (run) => {
    if (!urls.has(run.id)) urls.set(run.id, URL.createObjectURL(run.video));
    return urls.get(run.id);
  };

  const onSubmitRun = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const run = await saveRun({ video: file, selfScore, notes });
    setNotes('');
    await refresh();
    const best = bestRun((await listRuns()).filter((r) => r.id !== run.id));
    if (best) setMirror({ current: run, best });
  };

  const startDuel = (a, b) => setDuel({ a, b, winnerId: null });

  const judgeDuel = async (winner, loser) => {
    await updateRun(winner.id, { h2hWins: (winner.h2hWins ?? 0) + 1 });
    await updateRun(loser.id, { h2hLosses: (loser.h2hLosses ?? 0) + 1 });
    setDuel((d) => ({ ...d, winnerId: winner.id }));
    await refresh();
  };

  const best = bestRun(runs);

  return (
    <div style={pageStyle}>
      <header style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 26, fontWeight: 900, letterSpacing: '0.04em' }}>IRL DUNK</h1>
          <div style={{ color: '#94a3b8', fontSize: 13 }}>Mirror Triumph · Couch H2H — friendly competition only</div>
        </div>
        <button onClick={() => navigate(-1)} style={btnGhost}>✕ Exit</button>
      </header>

      <div style={cardStyle}>
        <div style={sectionTitle}>SUBMIT A RUN</div>
        <div style={{ color: '#94a3b8', fontSize: 12, marginBottom: 10 }}>
          Film your real dunk. The video stays on this device — nothing uploads in v1.
        </div>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
          <label style={{ fontSize: 13 }}>
            Self-score (0–50):{' '}
            <input
              type="number" min="0" max="50" value={selfScore}
              onChange={(e) => setSelfScore(e.target.value)}
              style={inputStyle} data-testid="self-score"
            />
          </label>
          <input
            placeholder="notes (dunk style, spot…)" value={notes}
            onChange={(e) => setNotes(e.target.value)} style={{ ...inputStyle, width: 200 }}
          />
          <input
            ref={fileRef} type="file" accept="video/*" capture="environment"
            onChange={onSubmitRun} style={{ display: 'none' }} data-testid="video-input"
          />
          <button style={btnPrimary} onClick={() => fileRef.current?.click()}>
            🎥 Record / upload run
          </button>
        </div>
        <div style={{ color: '#64748b', fontSize: 11, marginTop: 8 }}>
          Self-scores are PROVISIONAL. Verified scoring arrives with the review
          pipeline — nothing here is ever auto-scored or estimated.
        </div>
      </div>

      {mirror && (
        <div style={{ ...cardStyle, border: '1px solid rgba(250,204,21,0.35)' }}>
          <div style={sectionTitle}>MIRROR TRIUMPH — you vs your best</div>
          <div style={duoGrid}>
            <RunTile run={mirror.current} url={videoUrl(mirror.current)} label="THIS RUN" />
            <RunTile run={mirror.best} url={videoUrl(mirror.best)} label="PERSONAL BEST" />
          </div>
          <div style={{ marginTop: 10, fontSize: 15, fontWeight: 800, color: mirror.current.selfScore > mirror.best.selfScore ? '#facc15' : '#94a3b8' }}>
            {mirror.current.selfScore > mirror.best.selfScore
              ? '🏆 MIRROR TRIUMPH — new personal best (provisional)'
              : `Best still stands (${mirror.best.selfScore} vs ${mirror.current.selfScore})`}
          </div>
        </div>
      )}

      {duel && (
        <div style={{ ...cardStyle, border: '1px solid rgba(96,165,250,0.35)' }}>
          <div style={sectionTitle}>COUCH H2H — judges decide</div>
          <div style={duoGrid}>
            {[duel.a, duel.b].map((r, i) => (
              <div key={r.id}>
                <RunTile run={r} url={videoUrl(r)} label={i === 0 ? 'RUN A' : 'RUN B'} />
                <button
                  style={{ ...btnPrimary, width: '100%', marginTop: 8, opacity: duel.winnerId ? 0.5 : 1 }}
                  disabled={!!duel.winnerId}
                  onClick={() => judgeDuel(r, i === 0 ? duel.b : duel.a)}
                  data-testid={`judge-${i === 0 ? 'a' : 'b'}`}
                >
                  {duel.winnerId === r.id ? '🏆 WINNER' : 'Judge: this run wins'}
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      <div style={cardStyle}>
        <div style={sectionTitle}>RUN LIBRARY {best ? `· personal best ${best.selfScore}` : ''}</div>
        {runs.length === 0 && <div style={{ color: '#64748b', fontSize: 13 }}>No runs yet — film your first dunk.</div>}
        <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))' }}>
          {runs.map((r) => (
            <div key={r.id} style={{ display: 'grid', gap: 6 }}>
              <RunTile run={r} url={videoUrl(r)} label={r.id === best?.id ? '⭐ BEST' : ''} />
              <div style={{ display: 'flex', gap: 6 }}>
                {runs.length > 1 && (
                  <button style={btnGhost} onClick={() => startDuel(r, runs.find((x) => x.id !== r.id))}>⚔ H2H</button>
                )}
                {best && r.id !== best.id && (
                  <button style={btnGhost} onClick={() => setMirror({ current: r, best })}>🪞 Mirror</button>
                )}
                <button style={{ ...btnGhost, color: '#f87171' }} onClick={async () => { await deleteRun(r.id); refresh(); }}>
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function RunTile({ run, url, label }) {
  return (
    <div style={{ background: 'rgba(255,255,255,0.04)', borderRadius: 12, padding: 8 }}>
      <video src={url} controls playsInline style={{ width: '100%', borderRadius: 8, background: '#000', aspectRatio: '16/10' }} />
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, fontSize: 12 }}>
        <span style={{ fontWeight: 800, color: '#facc15' }}>{label}</span>
        <span style={{ color: '#e2e8f0' }}>
          {run.selfScore} <span style={{ color: '#64748b' }}>({run.status})</span>
          {(run.h2hWins || 0) + (run.h2hLosses || 0) > 0 && (
            <span style={{ color: '#94a3b8' }}> · {run.h2hWins}W-{run.h2hLosses}L</span>
          )}
        </span>
      </div>
      {run.notes && <div style={{ color: '#94a3b8', fontSize: 11, marginTop: 2 }}>{run.notes}</div>}
    </div>
  );
}

const pageStyle = {
  minHeight: '100vh', background: '#05070c', color: '#f8fafc',
  padding: '20px clamp(12px, 4vw, 40px)',
  fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
};
const cardStyle = {
  background: 'rgba(10,14,22,0.9)', border: '1px solid rgba(255,255,255,0.08)',
  borderRadius: 16, padding: 16, marginBottom: 16,
};
const sectionTitle = { fontSize: 12, letterSpacing: '0.12em', color: '#94a3b8', fontWeight: 800, marginBottom: 10 };
const btnPrimary = {
  padding: '10px 16px', borderRadius: 10, border: 'none', cursor: 'pointer',
  background: '#facc15', color: '#111827', fontWeight: 800, fontSize: 13,
};
const btnGhost = {
  padding: '8px 12px', borderRadius: 10, cursor: 'pointer', fontSize: 12,
  background: 'rgba(255,255,255,0.06)', color: '#e2e8f0', border: '1px solid rgba(255,255,255,0.12)',
};
const inputStyle = {
  background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.14)',
  color: '#f8fafc', borderRadius: 8, padding: '6px 8px', width: 64,
};
const duoGrid = { display: 'grid', gap: 12, gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))' };
