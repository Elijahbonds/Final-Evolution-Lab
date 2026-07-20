# M38 — BASKETBALL COMPLETE · Dunk Contest works all the way through

Copy this into Abacus with `files/` + `KNOWN-ERRORS.md`. Prerequisites: M35
(overlay + grounding) and M37 (camera v2 + guards) deployed. This batch makes
basketball playable end-to-end for the first time.

---

## PROMPT FOR ABACUS

### LIVE AUDIT (July 2026)
Dunk Contest: venue renders (M34 court), HUD works, but the PLAYER IS NEVER ON
SCREEN — the camera opens on an empty lane; the rival is a sunken fragment at
the frame edge; the flow never advances past "HOLD trigger" because the old
dead overlay is still mounted. Score stays 0–0 forever.

### FILES
| File | Fixes |
|---|---|
| `files/modes/DunkMode.ts` | v2.1 FINAL REPLACEMENT (supersedes M35's copy AND M27's). Everything from v2 (touch-first HOLD-CHARGE/release-launch, SLAM pulse, per-phase anti-stall watchdog, ball attached from spawn) plus: `camDirector.snapTo(player, rim)` at load and at every possession reset (frame one is framed — E9), heroRef/objectiveRef registered for FrameGuard, rival's turn is now watchable (camera cuts to the rival, their body arcs to the rim, then back to you), first to 21 ends in a real WIN/LOSS result. |

### WIRING
1. Drop the file in (it REPLACES any existing DunkMode).
2. Confirm the dunk route mounts TouchOverlay with the `dunk` verb set
   (CHARGE hold / SLAM / STYLE) and that the legacy PWR/FLSH/SIG/CHARGE/SLAM
   in-canvas buttons are deleted (M35 grep list).
3. Keyboard parity via M37 KeyboardMap: SPACE hold = charge, release = launch,
   J = SLAM, K = STYLE.
4. Run the KNOWN-ERRORS regression sweep.

## ACCEPTANCE (record all three)
1. **Full touch game on a phone viewport**: drive → hold CHARGE → release →
   SLAM on the pulse → flush + replay → rival turn is visible on camera →
   score climbs → first to 21 shows WIN or LOSS. Player visibly on screen the
   entire run (zero `[FEL-FRAME]` errors).
2. **Stall-proof**: deliberately ignore the SLAM window twice — both attempts
   auto-resolve as misses and play continues (zero stalls).
3. **Keyboard-only game** on desktop reaches a result the same way.
