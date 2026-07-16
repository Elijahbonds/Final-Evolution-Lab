/**
 * irlRuns — local-first store for IRL dunk runs (IndexedDB).
 *
 * v1 compliance posture: likeness video NEVER leaves the device — no upload
 * path exists here. Scores are SELF-REPORTED (status 'provisional') per the
 * PRQ integrity rules: the system never fabricates a metric, and provisional
 * is labeled as such until a review pipeline verifies it.
 *
 * Server seam: SubmissionAPI mirrors the platform competition API shape
 * (submit-score / mirror-triumph) so wiring a backend later is a transport
 * swap, not a rewrite.
 */

const DB_NAME = 'fel-irl';
const STORE = 'runs';

function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, { keyPath: 'id' });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

function tx(db, mode, fn) {
  return new Promise((resolve, reject) => {
    const t = db.transaction(STORE, mode);
    const store = t.objectStore(STORE);
    const out = fn(store);
    t.oncomplete = () => resolve(out?.result ?? out);
    t.onerror = () => reject(t.error);
  });
}

/**
 * @param {{ video: Blob, selfScore: number, notes?: string }} input
 * @returns {Promise<object>} the stored run record
 */
export async function saveRun({ video, selfScore, notes = '' }) {
  const run = {
    id: `run_${Date.now()}_${Math.floor(performance.now() * 1000) % 1000}`,
    createdAt: new Date().toISOString(),
    video,
    selfScore: Math.max(0, Math.min(50, Number(selfScore) || 0)),
    notes,
    status: 'provisional', // 'verified' only via the review pipeline (seam)
    h2hWins: 0,
    h2hLosses: 0,
  };
  const db = await openDb();
  await tx(db, 'readwrite', (s) => s.put(run));
  return run;
}

/** @returns {Promise<object[]>} newest first */
export async function listRuns() {
  const db = await openDb();
  const all = await new Promise((resolve, reject) => {
    const req = db.transaction(STORE, 'readonly').objectStore(STORE).getAll();
    req.onsuccess = () => resolve(req.result ?? []);
    req.onerror = () => reject(req.error);
  });
  return all.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
}

export async function updateRun(id, patch) {
  const db = await openDb();
  const run = await new Promise((resolve, reject) => {
    const req = db.transaction(STORE, 'readonly').objectStore(STORE).get(id);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  if (!run) return null;
  const next = { ...run, ...patch };
  await tx(db, 'readwrite', (s) => s.put(next));
  return next;
}

export async function deleteRun(id) {
  const db = await openDb();
  await tx(db, 'readwrite', (s) => s.delete(id));
}

/** Personal best among runs (verified outranks provisional, then score). */
export function bestRun(runs) {
  if (!runs.length) return null;
  return [...runs].sort((a, b) => {
    const v = (b.status === 'verified') - (a.status === 'verified');
    return v !== 0 ? v : b.selfScore - a.selfScore;
  })[0];
}

/**
 * Review-pipeline bridge — typed client against the FEL platform
 * competition API (the deployed app's routes). Configure via
 * REACT_APP_FEL_PLATFORM_URL (e.g. https://finalevolution.abacusai.app).
 *
 * PRIVACY: submissions carry METADATA ONLY (score, notes, client run id,
 * timestamps) — the likeness VIDEO never leaves this device until a
 * consent + storage flow exists on the platform side. Scores submitted
 * here stay 'submitted' until a human reviewer verifies them; nothing is
 * auto-verified.
 */
const PLATFORM_URL = (process.env.REACT_APP_FEL_PLATFORM_URL || '').replace(/\/$/, '');

export const SubmissionAPI = {
  /** True when a platform base URL is configured at build time. */
  isConfigured() {
    return PLATFORM_URL.length > 0;
  },

  platformUrl() {
    return PLATFORM_URL;
  },

  /**
   * POST /api/competition/submit-score — metadata-only review request.
   * @param {{ id: string, selfScore: number, notes?: string, createdAt: string }} run
   * @returns {Promise<object>} platform response (reviewRef expected)
   */
  async submitForReview(run) {
    if (!PLATFORM_URL) throw new Error('Review pipeline not connected: set REACT_APP_FEL_PLATFORM_URL');
    const res = await fetch(`${PLATFORM_URL}/api/competition/submit-score`, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        mode: 'irl_dunk',
        clientRunId: run.id,
        score: run.selfScore,
        notes: run.notes ?? '',
        recordedAt: run.createdAt,
        source: 'manual', // PRQ integrity: self-reported until reviewed
      }),
    });
    if (!res.ok) throw new Error(`submit-score failed: HTTP ${res.status}`);
    return res.json();
  },

  /**
   * GET /api/mirror-triumph — the platform's verified best for this athlete.
   * @returns {Promise<object>}
   */
  async fetchVerifiedBest() {
    if (!PLATFORM_URL) throw new Error('Review pipeline not connected: set REACT_APP_FEL_PLATFORM_URL');
    const res = await fetch(`${PLATFORM_URL}/api/mirror-triumph`, { credentials: 'include' });
    if (!res.ok) throw new Error(`mirror-triumph failed: HTTP ${res.status}`);
    return res.json();
  },
};
