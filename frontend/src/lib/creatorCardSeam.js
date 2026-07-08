/**
 * creatorCardSeam.js — Creator Card integration seam (interface only).
 *
 * Brain Brawl's "Save lesson" button calls saveLesson() with a micro-lesson
 * payload. Today this is a local stub (localStorage + console) so the demo
 * UX is complete; the real Creator Card system plugs in behind this exact
 * interface later — no UI changes required.
 *
 * Contract:
 *   saveLesson({ questionId, prompt, explanation, microLesson, taxonomy, savedAt })
 *     -> Promise<{ ok: boolean, id: string, storage: string }>
 */

const STORAGE_KEY = "fel_saved_lessons";

export async function saveLesson(lessonPayload) {
  const entry = {
    id: `lesson_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`,
    savedAt: new Date().toISOString(),
    ...lessonPayload,
  };
  try {
    const existing = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
    existing.push(entry);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(existing.slice(-100)));
  } catch (_e) {
    // storage unavailable (private mode) — still resolve; seam is best-effort
  }
  // eslint-disable-next-line no-console
  console.info("[creator-card-seam] lesson saved (stub)", entry.id);
  return { ok: true, id: entry.id, storage: "localStorage(stub)" };
}

export function getSavedLessons() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
  } catch (_e) {
    return [];
  }
}
