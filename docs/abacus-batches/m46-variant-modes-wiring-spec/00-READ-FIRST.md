# M46 — VARIANT 3D MODES: T-POSE WIRING SPEC (not a code batch)

**This is different from every batch before it.** M35 through M45 shipped
complete files because I (Claude, this repo) had built up full ownership of
those mode files across many iterations — I could confidently ship a
"REPLACES this filename" file because I knew exactly what was in it.

The modes below are **different code I have never seen the source of.**
They were discovered in this session's mode-library sweep, are clearly
Babylon.js 3D scenes (real venues, real lighting, HP bars, round counters),
but are NOT the files I rebuilt in M35–M45 — they have their own HUD
contracts, their own control schemes, and evidence of the exact same T-pose
bug (E16/E22) in shared code I've already fixed elsewhere. **I cannot
generate an accurate drag-and-drop file replacement for code I have not
read.** What I can give Abacus is a precise, evidence-backed wiring
instruction, plus the exact fix file (already shipped, already live) to
apply it with.

---

## WHAT WAS FOUND (live audit, screenshots on file)

| Mode | Route | Venue | Evidence |
|---|---|---|---|
| 1v1 Hoops | `/play/onevone` | Venice Beach Court | Character on court holds the classic arms-out-horizontal bind pose; separate HUD (`MOMENTUM` meter, `CAM FOLLOW` distance readout) from Dunk Contest's HUD — confirmed separate code. |
| 3v3 Streetball | `/play/threevthree` | Venice Beach Court | Same T-pose signature on multiple visible characters; own HUD (`AST` assist counter, `TO 21 · 89s` timer). Also shows a fog/skybox plane visibly bleeding across the court — a second, distinct rendering bug not present in any mode this session rebuilt. |
| Three-Point Shootout | `/play/threepoint` | Venice Beach Court | Same court/hoop asset family; not yet confirmed T-posed mid-shot but shares the same character-spawn code family as the two above. |
| Karate VS | `/play/karate-vs` | Shimogamo Dojo | 1v1 duel vs "Rival Sensei" with HP bars and its own 5-button tracking-combat scheme (`J` slash tracks motion, `K` heavy becomes a "Dragon" attack at full chi, `U` kick, `L` guard-hold) — a completely different combat system from Karate Endless. Visible character shows the same bind-pose signature at range. |

## THE FIX (one line, per mode, wherever it spawns its characters)

Every T-pose this session has traced back to the exact same root cause
(`KNOWN-ERRORS.md` E16/E22): a clip name gets requested that was never
registered on the live rig, `animator.play()` silently no-ops, and the rig
sits at bind pose. **The fix is already shipped and live**:
`docs/abacus-batches/m42-animation-reliability/files/anim/clipRegistry.ts`
— `installSafePlay(animator, modeId)`.

**Wherever these four modes call `CharacterLibrary.spawn(...)` and get an
`animator` back, add one line immediately after:**
```ts
import { installSafePlay } from '<path-to>/anim/clipRegistry';
// ... after CharacterLibrary.spawn():
installSafePlay(char.animator, 'onevone');   // (or the mode's own id)
```
This alone makes bind pose unreachable for that character — any clip name
these modes use that doesn't exist will now log a loud
`[FEL-ANIM] MISSING CLIP "..."` warning and substitute a real clip instead
of freezing at bind pose. No other change required to get instantly better
results; a full pass mapping these modes' specific gestures onto real clips
(the way `SPORT_CLIP` does for the M35–M45 modes) is the natural follow-up
once someone can see this code, but the one-line `installSafePlay` fix is
safe to apply blind because it can only ever improve on "silently frozen at
bind pose."

## SEPARATE, UNRESOLVED FINDING: 3v3 Streetball's fog/skybox bug
The 3v3 Streetball screenshot shows a horizontal white cloud band bleeding
across the mid-court area — looks like a skybox or fog plane intersecting
the playing surface. This is NOT a pattern seen in any of the ten venues
`VenueKit`/`rideWorlds` builds, so it's very likely coming from whatever
separate environment code these variant modes use. I don't have enough
visibility to diagnose the exact cause (could be a misplaced skybox mesh,
a fog range set incorrectly, or a missing horizon cutoff) — flagging it for
whoever has eyes on that file, rather than guessing a fix I can't verify.

## HOW TO GET ME REAL FIXES FOR THESE MODES
The honest next step, if these four (and the rest of the 12 previously-
unaudited modes) are worth the same treatment as the first ten: **export
their source** (the actual `.ts`/`.tsx` files Abacus's builder is running
for `/play/onevone`, `/play/threevthree`, `/play/threepoint`,
`/play/karate-vs`, and the rest) into this repo, the same way the original
ten modes' logic became mine to iterate on through M26 onward. Once I can
read them, they get the exact same playtest → diagnose → full-file-fix
treatment as everything already shipped this session — not a guess, not a
spec, an actual complete, drag-and-drop, tested fix.
