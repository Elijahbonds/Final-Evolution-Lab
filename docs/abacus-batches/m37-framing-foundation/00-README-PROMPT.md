# M37 — FRAMING FOUNDATION · camera v2 · FrameGuard/SpawnGuard · one keyboard · no 404s

Copy this document into Abacus with every file in `files/` plus
`KNOWN-ERRORS.md`. **Deploy M35 first** (single overlay + grounding) if it
isn't live yet — M37 builds directly on it. M37 is the foundation for the
family batches that follow (M38 basketball, M39 board sports, M40 precision
sports, M41 football): apply it once and every mode inherits correct framing,
loud regression guards, and a working keyboard.

---

## PROMPT FOR ABACUS

### LIVE AUDIT (screenshots on file, July 2026)
Full 10-mode sweep. The single biggest game-wide defect is **E9: the camera
never frames the action** — karate stares at the floor (fighters are two pairs
of arms at the bottom edge), the dunk player is entirely out of frame, the
football runner is invisible in the corner while touchdowns score. Plus
**E12**: every mode page 404s `/img/venues/*.jpg`.

### FILES
| File | Fixes |
|---|---|
| `core/CameraDirector.ts` | v2 REPLACEMENT (E9). Targets chest height (never feet), clamps pitch into [floor, cap] so the floor stare is impossible, auto-widens to fit two subjects (fight/court), `snapTo()` for correct frame-one framing, `setFixedBehind()` presets for precision sports. API superset of v1 — existing calls keep working. |
| `core/FrameGuard.ts` | E9 enforcement: every 2s projects the hero to screen space; off-screen twice → loud `[FEL-FRAME]` error + auto-recenter. `assertSpawned()` (E10/E11): a mode may not reach `playing` with an empty world or missing hero — `[FEL-SPAWN]` errors say exactly what's wrong. |
| `core/KeyboardMap.ts` | E13: THE one keyboard map (WASD stick, SPACE analog charge matching TouchOverlay's ramp, J/K/L/I = A/B/X/Y verbs, 1/2/3 dpad). Mounted once by the harness; delete every per-mode keydown listener. |
| `ui/venueThumbs.ts` | E12: procedural venue thumbnails (canvas gradient + glyph, cached data-URLs). Replace every `/img/venues/*.jpg` reference. |
| `core/gameFeel.ts` | The premium-feel toolkit every mode shares: InputBuffer (140ms — presses never feel eaten), coyote time (110ms grace), hit-stop (impacts feel heavy), decaying screen shake (small, short), haptics. Wire once in the harness (dt × timeScale(), one Shaker on ctx.feel) and every mode inherits it. |
| `KNOWN-ERRORS.md` | The project's regression ledger. Keep it in the repo root of the docs; run its REGRESSION SWEEP before every promote from now on. |

### WIRING
1. Replace CameraDirector; in every mode's `load()`, after the hero spawns,
   call `ctx.camDirector.snapTo(hero.position, objectiveOrNull)` (one line —
   guarantees frame one is framed).
2. ModeHarness: after `mode.load()` run `assertSpawned(...)`; create a
   FrameGuard wired to the mode's hero ref; start it on `playing`, stop+
   dispose on exit. Add `heroRef`/`objectiveRef` to ModeContext (modes set
   them in load — one line each).
3. Mount `mountKeyboard(bus)` once in the harness; grep-delete every other
   `keydown` listener in mode/game code.
4. Replace `/img/venues/` img srcs with `venueThumb(id)`; delete dead refs.
5. gameFeel: in the harness render loop pass `dt * timeScale()` to
   mode.update(); create one `Shaker(scene, camera)` and an `InputBuffer`,
   expose as `ctx.feel = { shaker, buffer, impact }`; call
   `buffer.press(btn)` on every button-down.
6. Run the KNOWN-ERRORS REGRESSION SWEEP.

## ACCEPTANCE
1. Karate + dunk + football, 60s recorded each: hero visibly framed ≥95% of
   the run; zero `[FEL-FRAME]` errors in console after the first auto-recover
   (ideally zero total).
2. Zero 404s on every mode route (network tab).
3. Keyboard-only run of dunk on desktop: WASD drive → SPACE hold-release →
   J slam at the pulse → score changes. Same run works with touch overlay.
4. Console sweep shows `[FEL-SPAWN] <mode>: OK` for all 10 modes.
5. KNOWN-ERRORS sweep: E1–E13 all green.
