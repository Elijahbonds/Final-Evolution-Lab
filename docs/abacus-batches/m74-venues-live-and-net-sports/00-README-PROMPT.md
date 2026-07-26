# M74 — Steps 2 & 3: venues wired into live modes, plus tennis and volleyball

Drag-and-drop for Abacus. Depends on **M73** being dropped first (it provides
`nexus/NexusWebScene.ts` and `nexus/venueSpecs.ts`).

---

## STEP 2 — the venues go live

M73 built and rendered 20 venues. They were sitting in a zip. This wires them
in.

### `core/NexusVenue.ts` — one call per mode

```ts
venue = mountVenue(ctx, 'basketball_h2h');   // replaces VenueKit.buildCourt(...)
…spawn characters…
venue?.hidePlaceholders();
// dispose(): venue?.dispose();
```

It's a helper rather than six copy-pasted blocks because each of the three
things it does is easy to omit and **invisible when omitted**:

1. **Camera bounds.** M64 added `CameraDirector.setBounds()` exactly for this.
   A venue that never calls it silently reverts to pre-M64 behaviour and the
   camera walks out of the world — that's E26 coming back.
2. **Placeholder removal.** Miss this and every player is on the court twice:
   one capsule stand-in, one real avatar, in the same spot.
3. **Total disposal.** A mode switch that leaves a sky dome behind shows the
   previous venue's sky over the new one, which reads as a grading bug rather
   than a leak.

### ⚠️ A real integration bug found while wiring — worth knowing

M73's loader named its ground mesh `nexus_ground`. M64's `CameraDirector`
occlusion probe recognises venue shell **by name**:

```ts
const VENUE_SHELL = /^(venue_ground|venue_box|wall_|park_floor|piste|…)/i;
```

because `VenueKit` builds those meshes without collision flags. A ground
called `nexus_ground` is **invisible to that probe** — so every M73 venue
would have had a camera that sinks through the floor and walls it can't see.
That is precisely E26, reintroduced by a naming mismatch.

Fixed in M73's `NexusWebScene.ts`: ground is now `venue_ground`, walls are
`wall_nexus`. **Re-drop M73 along with this batch** — the corrected file is
included in the M73 zip.

### Route → venue mapping

The web routes and the Nexus mode ids are different strings, and guessing
wrong yields a *silent* fallback to VenueKit. `ROUTE_TO_VENUE` in
`NexusVenue.ts` is the table:

| route | venue id |
|---|---|
| `/play/dunk` | `basketball_dunk` |
| `/play/onevone` | `basketball_h2h` |
| `/play/threevthree` | `basketball_3v3` |
| `/play/karate` | `karate_endless` |
| `/play/carnival` | `court_carnival` |

---

## STEP 3 — two new playable modes

You asked for the next modes, so: **tennis and volleyball**, chosen because
they're the same game underneath and the second one therefore costs a config
object rather than a rewrite.

### `core/RallyCore.ts` — the shared engine, and it is **tested by execution**

Tennis and volleyball differ only in scoring and touches-per-side. Everything
else — timing bands, shot planning, flight, net clearance, in/out — is shared.

Deliberately **Babylon-free**: it's arithmetic on plain numbers, which is what
lets it be *run* rather than only read.

```
node --experimental-strip-types files/tests/rally_test.ts
  → 37 passed, 0 failed
```

Those tests are shipped in `files/tests/`. They cover the parts that are easy
to get subtly wrong and impossible to eyeball:

- **deuce/advantage** — 3-3 is DEUCE, one point is AD IN and simultaneously
  AD OUT for the other side, and it takes **two clear points** to convert
- **rally scoring** — 3-3 at a target of 3 does *not* end the set; 4-3 doesn't
  either; the cap does
- **fault precedence** — a ball into the net is called `net`, never `long`,
  even when its landing point is also out. That's how the sport adjudicates it
- **touch limits** — volleyball's fourth touch faults, tennis's second does

Two design choices worth flagging because they're what make it feel like a
sport rather than a dice roll:

- **`early` and `late` are separate results**, not one "ok" band. They land at
  different depths, so timing reads as *placement*.
- **Weak contact arcs higher.** Counter-intuitive until you try the
  alternative: a flat trajectory on low power fires every mistimed ball into
  the tape, which players read as a bug. Verified by test —
  `weak.apex > perfect.apex`.

### `modes/NetSportMode.ts` + `TennisMode.ts` + `VolleyballMode.ts`

The factory owns meshes, input, animation and HUD. The two mode files are
config only — tennis is 1 touch / deuce scoring / 0.95m net, volleyball is
3 touches / rally-to-25 / **2.24m** net, and that net height alone is what
turns a weak dig into a ball stuck in the tape.

A fault still **flies before it lands**, rather than the ball vanishing —
that's what makes a net-cord read as a near miss.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/NexusVenue.ts` | game source `core/` |
| `files/core/RallyCore.ts` | game source `core/` |
| `files/modes/NetSportMode.ts` | game source `modes/` |
| `files/modes/TennisMode.ts` | game source `modes/` |
| `files/modes/VolleyballMode.ts` | game source `modes/` |
| `files/tests/rally_test.ts` | repo `tests/` (runnable, no build step) |

## WIRING

1. Drop **M73 first** (it carries the corrected shell names), then this batch.
2. Register the two modes in the mode registry and add routes `/play/tennis`
   and `/play/volleyball`.
3. In each existing basketball/karate/carnival mode, replace the
   `VenueKit.buildCourt(...)` line with `mountVenue(ctx, ROUTE_TO_VENUE[id])`
   and add `venue?.hidePlaceholders()` after spawning, `venue?.dispose()` in
   `dispose()`.
4. `swingClip` is currently `'jumpshot'` in both modes — a real racquet/spike
   clip should replace it; the comment in `TennisMode.ts` says so explicitly.

## ACCEPTANCE

1. `node --experimental-strip-types tests/rally_test.ts` → **37 passed**.
2. `/play/tennis` and `/play/volleyball` reach `#fel-ready[data-state="playing"]`
   and play a rally to a scored point.
3. Existing modes render the M73 venues, with **no doubled bodies** and no
   `[FEL-FRAME]` camera warnings.
4. `node tools/smoke.mjs --modes dunk,onevone,threevthree,karate,carnival,tennis,volleyball`
   → all PASS.

## WHAT I COULD NOT VERIFY HERE

Being explicit, because this is the honest half of the batch:

- **The modes are not type-checked against the real app.** I don't have the
  Abacus source, so imports like `ModeHarness`, `CharacterLibrary` and
  `SoundKit` are written to the contract I can read in earlier batches. Syntax
  and structure pass the batch gate; `tsc` in Abacus is the first real check.
  Expect small signature corrections — most likely `ctx.onGameOver` and the
  `SoundKit.startAmbient` ambient names.
- **`RallyCore` is fully tested; the modes are not.** The arithmetic is proven
  by execution; the glue that drives it is not, and cannot be until it runs
  in the app.
- **Feel is unplayed.** `aiSkill` (0.82 / 0.78) and the timing bands are
  reasoned defaults, not tuned numbers. First playtest will move them, and
  that's expected rather than a defect.
