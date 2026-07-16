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
 * Server seam — mirrors the platform competition API. All methods are
 * intentionally NOT implemented in v1 (local-only); the UI must treat
 * rejection as the normal case until the review pipeline exists.
 */
export const SubmissionAPI = {
  /** POST /api/competition/submit-score */
  async submitForReview() {
    throw new Error('Review pipeline not connected in local-only v1');
  },
  /** GET /api/mirror-triumph */
  async fetchVerifiedBest() {
    throw new Error('Review pipeline not connected in local-only v1');
  },
};
