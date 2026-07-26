# M77 — the routing job, and the reason it was mis-scoped

Repo + game source. Small batch; the value is in what it prevents.

---

## I GOT THE LAST AUDIT WRONG

I reported **nine modes "built but never routed."** Six of them were live.

I had probed `/play/skateboarding`, `/play/snowboarding`, `/play/surfing` —
but those modes declare `modeId: 'skateboard' | 'snowboard' | 'surf'`. I
guessed route names instead of reading them, and reported the guesses as
findings.

The corrected picture, verified by probing every real modeId:

```
19 live · 2 unrouted (the actual routing job) · 4 unbuilt (needs a mode)
```

**The routing backlog is two routes, not nine.**

## THE ROOT CAUSE — one mode, four names, nothing reconciling them

| Where | Name |
|---|---|
| Next.js route | `/play/skateboard` |
| `modeId` in the mode | `skateboard` |
| Venue id in `venueSpecs.ts` | `skateboarding` |
| Backend mode manager | `skateboarding` |

Four names for one thing and no table connecting them. That is not a
one-off — it produced **three separate bugs**:

1. **This bad audit** — guessed a route name, reported it as missing.
2. **M74 shipped duplicate tennis and volleyball modes** while working ones
   were already live, because nothing said "tennis exists."
3. **`applyArtCard` hunted `court_floor`/`ground`** for months — mesh names no
   venue has ever built (it's `venue_ground`). Every art card silently did
   nothing.

Same failure three times. So the fix is the table, not another careful look.

## `core/modeRegistry.ts` — one source of truth

Every mode this project has ever named, with route, modeId, venue id, backend
id, module path and an honest status:

- **`live`** — routed and responding
- **`unrouted`** — the module exists on disk, no route points at it
- **`unbuilt`** — named in the backend registry and/or `venueSpecs`, but **no
  mode module has ever been written**

That third status matters. Routing an `unbuilt` mode turns a clean 404 into a
runtime error, which is worse. `routableModes()` excludes them deliberately.

**`route` and `modeId` must stay identical.** They diverged informally for the
board sports and cost a full audit cycle; the tool now fails if they differ.

## `tools/route_audit.mjs` — makes "is it routed?" a command

Probes every registry entry against the live app *and* the files on disk:

```
LIVE     /play/skateboard    http=200  m55-board-sports-phase5
UNROUTED /play/dance         http=404  m75-dance-mode
UNBUILT  /play/acting        http=—    no module

19 live · 2 unrouted (routing job) · 4 unbuilt (needs a mode)
no drift
```

It flags four kinds of drift: `route !== modeId`; a registry entry whose module
isn't on disk (**the table lying is worse than no table**); a source `modeId`
that disagrees with the registry; and anything marked `live` that 404s or
marked `unrouted` that answers 200.

Wired into `green_check.sh --fel`, so this can't rot.

## THE ACTUAL ROUTING JOB — two routes

| Route | Module | Batch |
|---|---|---|
| `/play/dance` | `modes/DanceMode` | M75 |
| `/play/art` | `modes/art/ArtMode` | M28 — has existed unrouted since M28 |

Both modules exist and are complete. `ArtMode` is React (a canvas painter), not
a `ModeDefinition`, so it mounts like `MusicMode` does rather than through
`ModeHarness`.

## FILES

| File | Goes where |
|---|---|
| `files/core/modeRegistry.ts` | game source `core/` |
| `files/tools/route_audit.mjs` | repo `tools/` |

## WIRING

1. Register `/play/dance` → `DanceMode` (via `ModeHarness`, as with any
   `ModeDefinition`) and `/play/art` → `ArtMode` (React mount, as `MusicMode`).
2. Have the mode menu build from `playableModes()` rather than a hand-written
   list, so a new mode appears by adding one registry row.
3. Run `node tools/route_audit.mjs` after deploying — it should report
   **21 live · 0 unrouted**.

## ACCEPTANCE

1. `node tools/route_audit.mjs` → `no drift`, exit 0.
2. After wiring: `/play/dance` and `/play/art` return 200 and the audit shows
   **21 live · 0 unrouted · 4 unbuilt**.
3. `bash tools/green_check.sh --fel` → route registry check PASS.

## THE REAL BACKLOG — four modes that don't exist

Not a routing job. These are named in the backend mode manager and the Nexus
venue registry — and M73 even built venues for `brain_brawl`, `who_scene_it`
and `basketball_irl` — but **no mode module was ever written**:

- **`acting`** — the only one of the five creator disciplines with no playable
  surface. `VoiceCapture.ts` exists in M28; nothing plays it.
- **`irl`** (IRL Dunk) — the HealthKit-tracked real-world mode. On web this
  needs a different capture story than iOS assumed.
- **`brain_brawl`**, **`who_scene_it`** — quiz/party modes. Both have venues
  and registry entries and nothing else.

Worth deciding deliberately whether these ship or get removed from the
registries. Right now they inflate the mode count in the backend and in every
menu built from it, which is how a "20 mode" product is really 21 playable
surfaces and 4 promises.
