/**
 * creatorCardSeam.js — Creator Card integration seam (interface only).
 *
 * Brain Brawl's "Save lesson" button calls saveLesson() with a micro-lesson
 * payload. Today this is a local stub (localStorage + console) so the demo
 * UX is complete; the real Creator Card system plugs in behind this exact
 * interface later — no UI changes required.
 *
 * SHARED SCHEMA BY CONTRACT (no cross-branch imports): the creator-card
 * schema is owned by the card-system workstream. We reference it only by
 * contract id and emit cards in that shape:
 *
 *   contract: "fel.creator-card.lesson-capture/v1"
 *   card: {
 *     type:         "lesson",
 *     creator_type: "educator",          // dj | artist | dancer | producer | educator
 *     title:        string,              // micro-lesson title
 *     body:         string,              // micro-lesson body
 *     takeaway:     string,              // one-line takeaway
 *     taxonomy:     { category, skill }, // incl. music/dance categories
 *     source:       { kind: "brainbrawl_question", question_id, prompt },
 *     attachments:  []                   // future: masterclass links, clips
 *   }
 *
 * Interface:
 *   saveLesson({ questionId, prompt, explanation, microLesson, taxonomy })
 *     -> Promise<{ ok: boolean, id: string, contract: string, storage: string }>
 */

export const CREATOR_CARD_CONTRACT = "fel.creator-card.lesson-capture/v1";

const STORAGE_KEY = "fel_saved_lessons";

export async function saveLesson({ questionId, prompt, explanation, microLesson, taxonomy }) {
  const entry = {
    id: `lesson_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`,
    contract: CREATOR_CARD_CONTRACT,
    saved_at: new Date().toISOString(),
    card: {
      type: "lesson",
      creator_type: "educator",
      title: microLesson?.title || prompt,
      body: microLesson?.body || explanation || "",
      takeaway: microLesson?.takeaway || "",
      taxonomy: taxonomy || null,
      source: { kind: "brainbrawl_question", question_id: questionId, prompt },
      attachments: [],
    },
  };
  try {
    const existing = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
    existing.push(entry);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(existing.slice(-100)));
  } catch (_e) {
    // storage unavailable (private mode) — still resolve; seam is best-effort
  }
  // eslint-disable-next-line no-console
  console.info("[creator-card-seam] lesson card captured (stub)", entry.id, entry.contract);
  return { ok: true, id: entry.id, contract: CREATOR_CARD_CONTRACT, storage: "localStorage(stub)" };
}

export function getSavedLessons() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
  } catch (_e) {
    return [];
  }
}
