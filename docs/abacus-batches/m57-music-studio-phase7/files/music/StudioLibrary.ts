// StudioLibrary — the save/library layer for the Music Studio (M57).
// Covers the ask: "stream music, see all of a creator's songs, save them" —
// FEL-side, honestly: tracks live in localStorage today, with every point a
// real backend sync belongs at marked `SYNC SEAM`. When Abacus wires those
// four seams to its own storage/API, the library becomes cross-device and
// cross-user without touching the UI. External streaming (Spotify/Apple) is
// Phase 8's separate seam — nothing here pretends to be that.

import type { SequencerState } from './AudioEngine';
import type { KitId } from './SynthKit';

export interface TrackRecord {
  id: string;
  title: string;
  authorId: string;
  authorName: string;
  kit: KitId;
  bpm: number;
  swing: number;
  polished: boolean;
  /** The full pattern — enough to REPLAY and to REMIX. */
  sequencer: SequencerState;
  /** data: URL of the rendered mixdown WAV (2 bars) — instant playback. */
  mixdownDataUrl: string;
  remixOf: { id: string; title: string; authorName: string } | null;
  createdAt: number;
  plays: number;
  saves: number;
}

const KEY_TRACKS = 'fel_studio_tracks_v1';       // all published tracks visible to this device
const KEY_SAVED = 'fel_studio_saved_v1';         // track ids this user saved to their library

function readAll(): TrackRecord[] {
  try { return JSON.parse(localStorage.getItem(KEY_TRACKS) ?? '[]') as TrackRecord[]; }
  catch { return []; }
}
function writeAll(tracks: TrackRecord[]): void {
  // keep the newest 40 — data URLs are heavy; a real backend lifts this cap
  localStorage.setItem(KEY_TRACKS, JSON.stringify(tracks.slice(0, 40)));
}
function readSaved(): string[] {
  try { return JSON.parse(localStorage.getItem(KEY_SAVED) ?? '[]') as string[]; }
  catch { return []; }
}

export const StudioLibrary = {
  /** Publish a finished track to the library. */
  publish(rec: Omit<TrackRecord, 'id' | 'createdAt' | 'plays' | 'saves'>): TrackRecord {
    const full: TrackRecord = {
      ...rec,
      id: `trk_${Date.now()}_${Math.floor(Math.random() * 1e5)}`,
      createdAt: Date.now(), plays: 0, saves: 0,
    };
    writeAll([full, ...readAll()]);
    // SYNC SEAM: POST /api/studio/tracks  { full }  — server assigns id,
    // stores the mixdown in object storage, returns the canonical record.
    return full;
  },

  /** Every track on this device, newest first. */
  list(): TrackRecord[] {
    // SYNC SEAM: GET /api/studio/tracks?limit=… replaces the local read.
    return readAll();
  },

  /** All of one creator's songs — the "see everything they've made" view. */
  byAuthor(authorId: string): TrackRecord[] {
    return readAll().filter((t) => t.authorId === authorId);
  },

  get(id: string): TrackRecord | null {
    return readAll().find((t) => t.id === id) ?? null;
  },

  /** Count a play (called when the library actually starts audio). */
  countPlay(id: string): void {
    const all = readAll();
    const t = all.find((x) => x.id === id);
    if (t) { t.plays++; writeAll(all); }
    // SYNC SEAM: POST /api/studio/tracks/:id/play
  },

  /** Save someone's track to MY library. */
  saveToMyLibrary(id: string): void {
    const saved = readSaved();
    if (!saved.includes(id)) {
      saved.push(id);
      localStorage.setItem(KEY_SAVED, JSON.stringify(saved));
      const all = readAll();
      const t = all.find((x) => x.id === id);
      if (t) { t.saves++; writeAll(all); }
    }
    // SYNC SEAM: POST /api/studio/library { trackId } per user.
  },

  mySavedIds(): string[] { return readSaved(); },
  mySaved(): TrackRecord[] {
    const ids = new Set(readSaved());
    return readAll().filter((t) => ids.has(t.id));
  },

  remove(id: string): void {
    writeAll(readAll().filter((t) => t.id !== id));
  },

  /** Start a remix: returns the state to load into the editor + attribution. */
  beginRemix(id: string): { sequencer: SequencerState; kit: KitId; bpm: number; swing: number; remixOf: TrackRecord['remixOf'] } | null {
    const t = this.get(id);
    if (!t) return null;
    return {
      sequencer: JSON.parse(JSON.stringify(t.sequencer)) as SequencerState,
      kit: t.kit, bpm: t.bpm, swing: t.swing,
      remixOf: { id: t.id, title: t.title, authorName: t.authorName },
    };
  },
};

/** Blob → data: URL (stored inline today; object storage at the SYNC SEAM). */
export function blobToDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(r.result as string);
    r.onerror = () => reject(r.error);
    r.readAsDataURL(blob);
  });
}
