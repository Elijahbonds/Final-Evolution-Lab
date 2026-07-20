# M27 · BABYLON BATCH 3 — THE MODES (8 files)

Drop into Abacus AFTER M24 (anim core) + M26 (framework). This is your P3–P4 and
the rollout content behind P8–P10: the dunk proof mode in full, plus karate,
football, all three board sports, and the timing-sport family — each a
ModeDefinition on the shared cores, each individually wire-able so you can ship
dunk first (your plan), then flip the rest on one at a time WITHOUT new code.

---

## PROMPT FOR ABACUS

Wire these modes per your phased plan. P3–P4: route `/play/dunk` (Babylon) using
`DunkMode`; verify with the founder before enabling other modes' routes. The
remaining ModeDefinitions are complete and route-ready — enable each behind its
route after dunk passes playtest. Keep three.js modes serving any route not yet
flipped. Venue meshes: load the existing venue GLBs per mode and pass their
ground meshes into the definitions where required; venue boxes/set dressing per
M22 §6 remain your asset task — these modes run on any floor plane meanwhile.

## FILES
| File | What it is |
|---|---|
| `files/modes/DunkMode.ts` | PROOF MODE — approach/charge/style/eastbay movie/QTE/replay/rival turns to 21 |
| `files/modes/KarateEndlessMode.ts` | KO-gated waves, randomized mob variety, strikes/hit-reacts/knockdowns |
| `files/modes/FootballMode.ts` | 4-down drives, skinned pursuing defenders, jukes/spin/hurdle, survivable opening |
| `files/modes/BoardRunMode.ts` | One definition, three sports via config: rails, kickers, coins, lift-cable grind, YETI chase |
| `files/modes/TimingSportMode.ts` | Config family: tennis (swept-racket), penalty, derby, golf — timing windows + BallSim |
| `files/modes/modeConfigs.ts` | All per-mode tuning: parks, waves, downs, windows, yeti, lift |
| `files/index.ts` | Barrel: every ModeDefinition ready for routing |

## ACCEPTANCE (dunk gate first, then per-mode)
1. **Dunk (gate):** full attempt — drive (WASD/stick), charge (hold), style pick
   (d-pad), eastbay movie with ball hand-to-hand under the knee, QTE at the rim,
   flush + replay (two angles), rival takes its turn, first to 21 ends with a
   SessionResult. Zero MISSING CLIP logs, no black frames.
2. Karate: waves advance ONLY via KO count; three consecutive waves show
   different enemy tint/scale mixes; strikes/hit-reacts/knockdowns all animate.
3. Football: defenders visible, pursuing, evadable with animated jukes/spin; no
   contact before the 15-yd grace; TACKLED/TOUCHDOWN both reachable.
4. Board (snowboard config): coin line collectable (capped), lift cable
   grindable off the big kicker, yeti hit → knockdown → 12 s chase → escape.
5. Tennis config: 20 max-speed serves, zero tunneling through the racket
   (sweptHit), rally loop functions.
