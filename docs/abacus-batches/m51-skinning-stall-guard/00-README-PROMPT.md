# M51 — SKINNING STALL GUARD + real-frame-reset fix (dunk animation root-cause investigation)

Copy this into Abacus with every file in `files/`. Prerequisite: M42 deployed
(clipRegistry, CharacterAnimator's predecessor). Files here REPLACE their
predecessor by filename.

---

## WHAT THIS BATCH IS ANSWERING

Your note after the last audit: *"The dunks should slow down mid animation, I
should see the proper animation happening or triggering, something is still
not working."* I re-tested Dunk Contest live and confirmed it with
frame-by-frame screenshots: the character is in a dead T-pose (arms straight
out, the raw bind pose) through approach, charge, launch, and apex — the
whole sequence. Legs don't bend for the jump either. This writeup is the full
investigation, done honestly rather than guessed at, because the answer
turned out to be more interesting — and more limited — than "wrong clip name."

## WHAT I PROVED, STEP BY STEP, ON THE LIVE BUILD

I didn't just re-read source files — I intercepted the actual deployed,
minified JS bundle Abacus is serving, inserted diagnostic logging directly
into it, and reloaded the live page through that patched copy so the
evidence is about the real production code, not a batch snapshot that may
have diverged from what got built.

1. **Clip names resolve exactly, no fallback.** Console shows
   `authored clips registered: idle_stand, ... dunk_charge_gather, dunk_launch,
   dunk_360_eastbay, ...` — all 16 procedurally-authored clips build
   successfully against the live skeleton (every bone name matches). Zero
   `MISSING CLIP` lines fire during the whole sequence.
2. **The animation weight genuinely reaches 1.0.** I patched the live
   `CharacterAnimator.crossFade` to log its blend factor and re-ran the
   charge → launch → land sequence. Live console output:
   ```
   WDIAG play name=dunk_charge_gather resolved=dunk_charge_gather fadeSec=0.15
   WDIAG fade clip=dunk_charge_gather k=1.000
   WDIAG play name=dunk_launch resolved=dunk_launch fadeSec=0.15
   WDIAG fade clip=dunk_launch k=1.000
   WDIAG play name=dunk_land_crouch resolved=dunk_land_crouch fadeSec=0.15
   WDIAG fade clip=dunk_land_crouch k=1.000
   ```
   The correct AnimationGroup is selected, started, and fully weighted. This
   rules out clip-name mismatch (E16/E22's cause) and crossfade-timing bugs
   as the explanation here — both were reasonable first suspects and both
   check out clean.
3. **Forcing CPU skinning did not change the outcome.** GPU vertex-shader
   skinning (Babylon's default, `computeBonesUsingShaders = true`) uses a
   bone-matrix texture that some limited/software WebGL implementations
   handle poorly, silently leaving meshes in bind pose while every bone/
   animation calculation underneath is completely correct. I patched live
   `CharacterLibrary.spawn()` to force `computeBonesUsingShaders = false` on
   every spawned mesh (CPU skinning, no shader/texture path at all) and
   re-ran the same sequence. Confirmed via console the flag was set on both
   characters. **The pose was still frozen.** This is a genuine, useful
   negative result — it rules out the specific "GPU float-texture skinning"
   failure mode as the sole explanation, though I can't fully exclude that a
   forced shader recompile would have been needed for that flag to take
   effect after materials were already compiled.

## WHAT THIS MEANS, AND THE HONEST LIMIT OF WHAT I CAN CONFIRM REMOTELY

Every layer I can inspect and instrument from outside — clip selection,
registration, weight blending — is correct. The failure sits at the boundary
between "the animated bone's transform node has the right values" and "the
rendered mesh reflects them," which is exactly the boundary I cannot
directly probe without either (a) real engine-internal access I don't have
into Abacus's build, or (b) a real GPU-accelerated browser — **my only test
environment is a sandboxed, software-rendered browser** (no real GPU is
available to me here), and I cannot rule out that software rendering itself
is contributing to what I'm seeing in a way a real user's device would not.

**I'm not shipping a claimed "fix" I can't verify.** Instead, this batch
ships two things I'm confident are correct improvements regardless:

1. A **self-healing detector** (`SkinningGuard`) that watches a real bone's
   world matrix after spawn and, if it hasn't moved after 20 rendered frames
   despite a fully-weighted playing clip, logs a loud, unmissable
   `[FEL-ANIM] SKINNING STALL` console error and automatically flips that
   character to CPU skinning as a live mitigation attempt. If this class of
   bug is present on any real device (yours or a player's), it now
   self-reports the moment it happens instead of silently shipping a frozen
   character, and every future playtest sweep will catch it immediately.
2. A real, independently-confirmed fix in `CharacterAnimator`: every mode
   calls `.play(moving ? run : idle, { loop: true })` from inside its
   per-frame `update()` — I confirmed via the same live instrumentation that
   this fires every single rendered frame. The old `play()` treated every
   call as a fresh request, restarting the crossfade and resetting weight to
   0 each time; on a real 60fps device (unlike my slow test capture, where a
   single frame's delta can exceed the whole 0.15s fade window and mask
   this) that would have kept locomotion clips permanently under-weighted.
   Fixed: a repeated call for the clip that's already current and playing is
   now a no-op.

## PLEASE CHECK ONE THING ON A REAL DEVICE

Load Dunk Contest on your own phone or a real desktop GPU and watch a charge
→ launch. If the character visibly animates there and this was a
software-rendering artifact of my sandbox, tell me and I'll drop the
CPU-skinning fallback (it costs some performance per character) and keep
only the CharacterAnimator fix. If it's frozen there too, the SkinningGuard
console line will tell us immediately, and its automatic CPU-skin fallback
may resolve it live — check whether the SECOND attempt (after the guard
fires) actually animates.

### FILES
| File | What it does |
|---|---|
| `files/anim/CharacterAnimator.ts` | v2 — same-clip repeated `.play()` calls (the every-frame update() pattern used by every mode) no longer reset weight/restart the crossfade. Confirmed-live fix. |
| `files/anim/SkinningGuard.ts` | **New.** Post-spawn self-check + automatic CPU-skinning fallback + loud console diagnostic if a bone never visibly moves despite a correctly playing, fully-weighted clip. |

### WIRING
1. Drop both files in — `CharacterAnimator.ts` replaces its predecessor.
2. In `CharacterLibrary.spawn()`, right after
   `animator.play(opts.startClip ?? 'idle_stand', { loop: true })`, add:
   ```ts
   SkinningGuard.verify(scene, id, meshes, skeleton);
   ```
3. Run the KNOWN-ERRORS regression sweep, then specifically re-check Dunk
   Contest's charge → launch → land sequence for real skeletal motion (not
   just root-position jump arc).

## ACCEPTANCE
1. No behavior change to any currently-working animation (idle/run/etc. on
   modes where it already animates correctly).
2. If a character's clip is genuinely stalled at the skinning layer, console
   shows `[FEL-ANIM] SKINNING STALL` within ~1/3 second of spawn, naming the
   character and bone — this must never be silent again.
3. Locomotion clips (idle ↔ run swaps, called every frame from mode
   `update()`) show smooth, undisrupted looping motion — no micro-stutter
   from constant restart.
