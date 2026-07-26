# M75 — Dance mode: the audit you asked for, and the gap it found

Depends on **M73** (venue system) and **M74** (`NexusVenue`).

**Prerequisites already deployed or shipped alongside:**
`anim/restPose.ts` (M64 — `buildQuatClip`/`eulerQ`, live),
`nexus/NexusWebScene.ts` (M73 — the venue loader `venueSpecs.ts` builds against),
`core/NexusVenue.ts` (M74).

---

## THE AUDIT — music, creator card, dance

You asked where these stood. I probed the live build rather than guessing:

| Surface | Route | Status |
|---|---|---|
| **Music mode** | `/play/music` | ✅ **live and good** |
| **Music studio** | `/studio` | ✅ live |
| **Marketplace** | `/market` | ✅ live |
| **Creator Hub** | `/creator` | ❌ **404** — `CreatorHub.tsx` exists in M28, never routed |
| **Art mode** | `/play/art` | ❌ 404 — `ArtMode.tsx` exists in M28, never routed |
| **Dance mode** | `/play/dance` | ❌ **404, and no mode ever existed** |

**Music is genuinely shipped**, and it's good: a 6-track step sequencer
(Hat/Open/Clap/Bass/Lead/FX × 16), BPM and swing, Shard-gated kits
(STREET / NEON 200◆ / DUST 400◆), BUILD/PERFORM tabs, publish-to-library with
an optional Spotify/Apple link, and Cell coaching in the footer. That's the
BandLab-shaped sequencer from the top of this project, live.

**Creator Card is half-built.** The type system is genuinely good — one social
object across five disciplines (`sport | music | art | dance | acting`) with a
discriminated `ArtPayload` per discipline, rarity tiers, and a server API in
`creatorCardApi.ts`. The marketplace that *sells* cards is live. **The hub that
authors them is a 404.** So cards can be traded but not made.

**Dance was the real gap**, which is why this batch is dance.

### Why dance never shipped

M28 shipped `ChoreographyEngine` — a good one: beat grid, ±40/90/200 ms
windows, combo scoring. It shipped with this comment:

> `// Clip library — ids resolve via DANCE_ALIASES until the authored pack lands.`

The authored pack never landed and `DANCE_ALIASES` was never written. Every
one of the eight clip ids resolved to **nothing**. The engine had nothing to
play, so no mode was ever built on it, so the route was never added. One
missing table stalled an entire discipline.

---

## WHAT SHIPPED

### `core/DanceCore.ts` — the engine's arithmetic, extracted and **tested**

M28's engine is welded to `CharacterAnimator`, so none of its timing could be
tested without a rig. This is the same arithmetic, animator-free.

**Judging windows and point values are byte-identical to M28's** — preserved,
not quietly re-tuned. There's a test asserting exactly that.

```
node --experimental-strip-types files/tests/dance_test.ts
  → 32 passed, 0 failed
```

It also adds the piece M28 was missing: **a routine generator**. Seeded and
deterministic, because `Math.random()` would make "retry" hand the player a
different chart. Tested: same seed → identical routine; and **no step ever
starts before the previous one ends**, so a routine can't ask you to begin a
windmill halfway through a six-step.

Stars are computed from **accuracy, not score** — score scales with routine
length, so a long easy chart would otherwise out-star a short hard one. Also
tested.

### `anim/danceClips.ts` — the table that was missing

Eight procedural clips built with M64's `buildQuatClip`, so targets resolve
from the live skeleton and a missing bone warns instead of breaking. Bone
names UNPREFIXED per `AvatarSkeletonSpec.md`.

**Honest status: these are procedural stand-ins, not mocap.** They're on-beat,
readable and clearly distinct from each other, which is what makes the rhythm
game playable — they are not finished dance. `DANCE_ALIASES` (finally written)
means any clip that fails to build falls back to motion that definitely
exists, so the mode is always playable, and swapping in an authored pack later
needs no code change.

The arm wave is the one worth reading: the forearm is keyed **a beat behind**
the shoulder. Key them together and it reads as a shrug.

### `modes/DanceMode.ts` + the `dance` venue

**Timing runs on the AUDIO clock, not the frame clock.** This is the one
decision that matters in a rhythm game: `update(dt)` arrives on
requestAnimationFrame, and a single dropped frame shifts judging against the
music. Players feel 30 ms of drift immediately. Every timing call takes
`AudioContext.currentTime`; the frame loop only asks what time it is in the
song.

The venue — **The Cypher** — is a neon stage with a lit deck, crowd and four
coloured lamps, rendered and verified. Its camera sits closer and lower than
any sports preset: in dance the body *is* the gameplay, so the avatar has to
be legible rather than surveyed from a stand.

> Caught by rendering it: at podium scale 1.6 the deck sits at y=0.8 while the
> dancer stood at y=0.4 — knee-deep in the stage. Same class as the M69
> groundSnap bug, authored instead of spawned. Fixed and re-rendered.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/DanceCore.ts` | game source `core/` |
| `files/anim/danceClips.ts` | game source `anim/` |
| `files/modes/DanceMode.ts` | game source `modes/` |
| `files/nexus/venueSpecs.ts` | game source `nexus/` — **REPLACES M73's** (adds `dance`) |
| `files/tests/dance_test.ts` | repo `tests/` — runnable, no build step |

## WIRING

1. Register `DanceMode` and add the route **`/play/dance`**.
2. `AudioEngine` needs `context`, `startTrack({bpm,bars})` and `stop()`. M28's
   and M57's engines both have a context; the two calls are optional-chained,
   so the mode runs (silently) if they're absent — check the console for the
   audio-clock fallback warning.
3. `animator.registerClip?.(id, group)` is the seam used to add the dance
   clips. If `CharacterAnimator` names that differently, this is the one line
   to change.

## ACCEPTANCE

1. `node --experimental-strip-types tests/dance_test.ts` → **32 passed**.
2. `/play/dance` reaches `data-state="playing"`, counts in one bar, and plays a
   routine to a star rating.
3. Console shows `[FEL-ANIM] dance clips: 8 built procedurally` — any
   `falling back to aliases` entry names a rig problem.
4. Taps register as PERFECT/GREAT/GOOD/MISS with a visible combo.

## NOT DONE — and worth deciding on next

- **`/creator` is still a 404.** `CreatorHub.tsx` and `creatorCardApi.ts` exist
  in M28. This is the biggest remaining hole in the product, because the
  Creator Card is the object that ties all five disciplines together — and
  right now cards can be sold but not authored. It's a routing + wiring job,
  not a build-from-scratch job.
- **`/play/art` is still a 404** — `ArtMode.tsx` exists, same situation.
- **The dance clips are stand-ins.** Replacing them with an authored pack is
  the single biggest quality jump available in this mode.
- **The mode is not type-checked against the Abacus source** — same limit as
  M74. `DanceCore` is proven by execution; the glue is not.
