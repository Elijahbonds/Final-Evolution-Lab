# M57 — PHASE 7: THE FEL MUSIC ACADEMY (creation studio, save/library/remix, zero-asset synthesis)

Copy this into Abacus with every file in `files/`. Prerequisite: the M56
wiring action — `/play/music` must route to a component (it 404s today).
`StudioMode.tsx` REPLACES M28's `MusicMode.tsx` as that route's component;
`AudioEngine.ts` REPLACES M28's file by name; `SynthKit.ts` and
`StudioLibrary.ts` are NEW.

---

## PROMPT FOR ABACUS

### The template, honestly applied
Reference: the loop that makes in-browser music platforms (BandLab-class)
sticky — a real groovebox, unlockable sounds, one-tap mastering,
publish-to-library, per-creator song pages, and remix-with-attribution.
Mechanics template only; all code and content original. The presentation is
**THE FEL MUSIC ACADEMY** — a warm, vibrant music-school hub with an
original mentor (Professor Okta, rotating craft tips). Per the standing IP
rule: original name/design, no real-person likeness, no franchise or show
references of any kind.

### 1. The fatal bug this fixes first
M28's MusicMode loads eight WAVs from `/audio/kits/808/*.wav` — files that
were never shipped. Even once the route is wired, it would boot a SILENT
studio. `SynthKit.ts` synthesizes every instrument offline at load (same
zero-external-asset philosophy as SoundKit/M43): the studio can never 404
its own sounds. Three kits ship: STREET (free), NEON (200 Shards), DUST
(400 Shards) — each a genuinely different sound palette, all synthesized.

### 2. What's REAL in this batch
- **The groovebox** — M28's proven 16×8 lookahead sequencer, kept, plus
  BPM/swing and the Perform rhythm layer (tap-scoring over your own beat).
- **One-tap MASTER** — a real compressor + shelf chain on the master bus,
  toggleable live, and applied to the saved mixdown.
- **Publish → Library → per-creator pages** — render a real 2-bar WAV
  mixdown, store it, browse everything, see ALL of one creator's songs,
  play them (play counts), SAVE them to your library (save counts).
- **REMIX** — one tap loads any published track's full pattern into the
  editor with permanent "remix of X by Y" attribution on the new track.
- **Kit unlocks + Cell assist** — "CELL: LAY A FOUNDATION" (50 Shards)
  writes a musically-locked starting pattern (kick/bass agree, snare
  backbeat, breathing hats — a real local generator).

### 3. Where the SEAMS are (marked in-code, never faked)
- **Shards economy** — `spendShards(cost, reason)` prop; unwired = free +
  console note. Wire it to the real wallet.
- **Cell/Nexus** — `cellFoundation()` is the exact plug point for a real
  LLM call; same input/output shape, swap the internals.
- **Backend sync** — `StudioLibrary` is localStorage today with four
  `SYNC SEAM` comments (publish / list / play-count / save) marking the
  API calls that make it cross-device and cross-user.
- **Spotify/Apple Music** — Phase 8's separate batch. Nothing here
  pretends to stream external catalogs.

### FILES
| File | What it does |
|---|---|
| `files/music/SynthKit.ts` | **New.** Offline-synthesized kits (3 palettes × 8 instruments), zero asset files. |
| `files/music/AudioEngine.ts` | v2 — adds `loadBuffer`/`swapKit`, `masterPolish`, full-mix `renderMixdown`. REPLACES M28's file. |
| `files/music/StudioLibrary.ts` | **New.** Publish/list/by-creator/play/save/remix, localStorage + marked SYNC SEAMs. |
| `files/music/StudioMode.tsx` | **New (replaces MusicMode.tsx as the route component).** The full Academy UI. |

### WIRING
1. Route `/play/music` → `StudioMode` (this is the M56 404 fix — the hub
   card should read "Music Academy" or similar).
2. Pass real props when available: `profile` ({id, name} of the signed-in
   creator — REQUIRED for per-creator pages to be meaningful),
   `spendShards` (wallet), `onPublish` (existing Creator Card pipeline —
   the M28 contract is preserved).
3. The four `SYNC SEAM` comments in StudioLibrary are the backend TODOs.
4. No modeVerbs/TouchOverlay changes — this is a 2D touch-first UI.

## ACCEPTANCE
1. The studio boots with AUDIBLE instruments (no network requests for any
   audio file). Toggling cells + PLAY produces a beat with a moving
   playhead; BPM and swing audibly change it.
2. MASTER ON audibly glues/brightens the mix, live.
3. NEON/DUST prompt for Shards (or log the seam note), then swap the whole
   kit's sound without touching the pattern.
4. CELL: LAY A FOUNDATION writes a groove where kick and bass lock and the
   snare sits on the backbeat — then it's editable like anything else.
5. PUBLISH renders a real WAV, and the LIBRARY tab plays it back, counts
   plays, saves it to "my library", and shows a creator's full song list
   via their name chip.
6. REMIX loads any track's pattern into the editor and the re-published
   track carries "remix of … by …" forever.
7. PERFORM mode scores taps against the audible grid (PERFECT/GOOD/EARLY/
   MISS with combo), exactly as M28 intended.
