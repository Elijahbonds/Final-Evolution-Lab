# M28 — CREATIVE MODES · Phases 11–14 (Creator Card × 5 disciplines)

Copy this document into Abacus with every file in `files/`. This is the revised,
drag-and-drop version of the Phases 11–14 package: Music, Art, Dance, Acting +
the unified Creator Hub and full five-discipline Creator Card.

---

## PROMPT FOR ABACUS

Implement Phases 11–14 using these files. **The gate stands:** do not start
Phase 13 (Dance) or any animation-driven piece until Phase 1 animation
acceptance has passed (recording: walk/jog/sprint/strafe + three distinct
strikes, zero T-pose frames). Phases 11–12 (Music, Art) are 2D/audio and may
run in parallel with animation work. Build order for fastest visible win:
**Art first** (smallest surface; an art card visibly reskinning a court proves
the card round-trip), then Music, then Dance, then Acting.

## REVISIONS APPLIED TO THE DRAFT (read before wiring)
1. **Mirror pairs fixed for the real skeleton.** The draft's `MIRROR_PAIRS`
   used `mixamorig:` prefixes — the shipped rig's bones are UNPREFIXED
   (`LeftArm`, `RightUpLeg`… verified from elijah-hero.glb). With the old
   names, mirroring would silently no-op. `files/anim/mirroredClips.ts`
   implements mirroring correctly as a clip-track swap + rotation reflection
   at registration time (never a negative root scale — that inverts winding).
2. **Animator option names aligned.** The Babylon CharacterAnimator (M24) uses
   `fadeSec`, not `blendMs`; `mirrored` is honored by registering a `.M`
   variant clip (see mirroredClips) — `play(name, { mirrored: true })` resolves
   to `name.M`. ChoreographyEngine updated accordingly.
3. **Music Perform-layer bugs fixed:** the draft's `onStepAudible` closure
   captured a stale `mode` (perform taps would never register after toggling);
   and `expectedRef` grew unbounded (un-hit steps never expired → late taps
   scored against old notes). Fixed with a mode ref + 250 ms expiry-as-miss.
4. **Dance clip dependency made explicit:** `DANCE_LIBRARY` ids don't exist in
   any asset yet. `mirroredClips.ts` also registers alias fallbacks
   (toprock→walk, bounce→idle sway, spin→roundhouse, freeze→guard…) so the mode
   RUNS today; the authored dance pack replaces them without code changes.
5. **Server API added (was missing entirely):** `files/server/creatorCardApi.ts`
   — save/publish/remix with the license gate enforced SERVER-side, discipline
   validation, remix graph, **creator royalty on remix** (the retention loop),
   and a moderation queue: music stems and acting audio are UGC — they enter
   `pending_review` before public listing (same trust model as Who Scene It).
6. Compliance kept verbatim: `licenseAccepted` checkbox required; acting ships
   AUDIO-ONLY (no likeness capture) until legal clears; kit samples must be
   original/CC0.

## FILES
| File | Purpose |
|---|---|
| `files/creator/CreatorCardTypes.ts` | Five-discipline card model + sport designation |
| `files/creator/CreatorHub.tsx` | Unified entry: primary/secondary, sport designation, license gate |
| `files/server/creatorCardApi.ts` | Save/publish/remix + royalty + moderation queue (NEW) |
| `files/modes/music/AudioEngine.ts` | Lookahead sequencer + swing + offline stem render (WAV) |
| `files/modes/music/MusicMode.tsx` | Build grid + Perform rhythm layer (closure/expiry fixes) |
| `files/modes/art/ArtMode.tsx` | Canvas painter: brush/fill/shapes/spray/mirror, palettes, undo |
| `files/modes/art/applyArtCard.ts` | Babylon: art card → court/board/kit/UI texture |
| `files/modes/dance/ChoreographyEngine.ts` | Beat-grid routine builder + performance judging |
| `files/anim/mirroredClips.ts` | Correct mirrored playback + dance alias fallbacks (NEW) |
| `files/modes/acting/VoiceCapture.ts` | Audio-only scene prompts + recorder |

## ECONOMY WIRING (extends Phase 6; server-side only)
Earn: publish card (coins) · your card gets remixed (coin royalty — implemented
in creatorCardApi). Spend (shards): premium kits, brush sets, dance clip packs,
card slots beyond 3, featured placement. No client-side minting anywhere.

## ACCEPTANCE (per phase, unchanged + additions)
1. Recording of the working mode + console proof + files touched.
2. One card of that discipline ROUND-TRIPPED: created → saved → reloaded →
   applied in-game (art card visibly reskins a court; music card's beat plays
   in the hub; dance card's routine fires as a dunk celebration).
3. Phase 13 gate: avatar performs a 3-clip routine, including one MIRRORED
   step, with zero T-pose frames — if this fails, Phase 1 did not pass.
4. Server: unlicensed card rejected (422); remix pays the parent creator's
   royalty (ledger entry); music/acting cards sit in pending_review until
   approved.
