# M30 — ONE-BUG-ALL-MODES FIX · Clip Name Suffix (live audit, verified)

Copy this document into Abacus with both files. Small batch, deploy immediately.

---

## PROMPT FOR ABACUS

Live playtest of every mode route (July 2026): the M29 hotfix landed correctly —
modes boot to the venue splash and TAP TO START, the watchdog works, the touch
overlay renders (MOVE/PWR/FLSH/SIG/CHARGE/SLAM). **One remaining bug breaks the
animation layer in every mode, and the console names it exactly:**

```
[FEL-ANIM] MISSING CLIP "run_forward" — no exact/alias match in
[guard_c58, high_kick_c59, hook_c60, jab_c61, jumpshot_c62, roundhouse_c63,
 run_c64, uppercut_c65, walk_c66, idle_stand, strafe_left, ... dunk_360_eastbay, ...]
```

### Diagnosis (exact)
`CharacterLibrary.spawn()` uses `instantiateModelsToScene((n) => n + '_c' + N)`
— that rename applies to **AnimationGroups too**, so the GLB's clips register as
`guard_c58`, `run_c64`… The alias table maps `run_forward → run`, which no
longer exists under that name → every GLB-clip request falls through to the
first-available fallback → every character in every mode plays the same wrong
clip. Note what DOES work: the authored clips (`idle_stand`, `dunk_360_eastbay`,
jukes, etc.) register post-instantiation with clean names — which is why the
dunk partially behaves while locomotion and karate strikes are broken.

### The fix (surgical, two files)
1. `files/CharacterLibrary.ts` (v3 drop-in): after instantiation, **restore each
   AnimationGroup's original name** (`g.name = g.name.replace(/_c\d+$/, '')`).
   Node/mesh renames stay (they prevent scene-name collisions); only animation
   groups get their names back — per-spawn groups are already per-instance
   objects, so name restoration cannot cross-target other spawns.
2. `files/clipResolver.ts` (v2 drop-in): defense-in-depth — resolution also
   normalizes candidate names by stripping `_c\d+$`, so even a future re-suffix
   cannot reproduce this class of bug. Missing-clip logging unchanged (it is
   what caught this).

### Also fix while in here (cosmetic, seen on every route)
- A 404 fires on each mode page — the BootSplash venue art
  (`/img/venues/*.jpg`) doesn't exist yet. Either add the five venue images or
  keep the gradient fallback silently (drop the `url()` when the image 404s).

## PER-MODE VERIFICATION AFTER DEPLOY (all four were audited broken the same way)
| Mode | Verify |
|---|---|
| Dunk | Approach plays `run` (not a frozen pose); charge → gather; eastbay end-to-end; ZERO `[FEL-ANIM]` errors in a full first-to-21 |
| Karate | Idle stance + strikes (jab/hook/roundhouse via aliases) + hit reacts + KO falls; wave clears only by KO |
| Football | Runner sprint cycle; jukes/spin/tackled clips; defenders animate |
| Skate | Cruise pose + jump/land + trick clips fire |
| All | Console shows zero MISSING CLIP across one full session per mode |

## ACCEPTANCE
1. One recording per mode above, each with the console visible at the end
   showing no `[FEL-ANIM] MISSING CLIP` entries.
2. The dunk gate (M27) now fully passes: eastbay with ball hand-to-hand under
   the knee → flush → two-angle replay → rival turn.
3. No 404s on mode boot.
