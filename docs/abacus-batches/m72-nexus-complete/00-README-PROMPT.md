# M72 — Nexus is now actually the engine it claimed to be: 20/20 modes, data-driven, verified

Repo-side batch. Nothing goes into Abacus.

---

## WHAT "FINISH FEL WITH NEXUS" MEANT HERE

"Finish" needs a definition you can hold someone to, so here is the one I
used and delivered against.

`NexusProject.json` has always claimed:

> *"All scenes are JSON-defined NexusScene descriptors rendered by
> NexusSceneView via SwiftUI Canvas."*

**None of that was true.** M70 found the shape of it; this batch closes it:

| | before | after |
|---|---|---|
| Scene descriptors that exist | 1 of 20 | **20 of 20** |
| Descriptors that actually **load** | **0** | **20** |
| Swift code that reads a descriptor | none | `NexusSceneLoader` |
| Scenes at runtime | hardcoded `NexusScene.default(for:)` | **loaded from JSON, with a fallback** |
| Verified by | nothing | the real loader, all 20 modes, on Linux |

That is Nexus finished as an *engine*: the declared architecture is now the
built one, across every mode.

---

## THE FINDING THAT MADE THIS NECESSARY

M70 reported the descriptors as orphaned. It was worse than orphaned.

The single descriptor that shipped was **valid JSON and completely
undecodable**. Swift synthesizes `Codable` for an enum-with-associated-values
and for `CGPoint` in a specific shape:

```jsonc
// what Swift actually expects
"position":   [0.35, 0.72]                                   // CGPoint → ARRAY
"components": [ { "skeleton": { "category": "Plyometric", "amplitude": 1 } } ]
```

The hand-written file used:

```jsonc
"position":   { "x": 0.35, "y": 0.72 }                       // ✗
"components": [ { "type": "skeleton", "category": "plyometric", … } ]   // ✗
```

Proven, not inferred — decoded with the real types:

```
DECODE FAILED: typeMismatch(Swift.Array<Any> …
  codingPath: entities[0].transform.position
  "Expected to decode Array<Any> but found a dictionary instead.")
```

**"It parses" is not "it loads."** Nothing caught this because nothing ever
tried to load it.

---

## WHAT SHIPPED

### 1. `NexusSceneLoader.swift`

Loads `<mode>.nexus.json` from the bundle, decodes into `NexusScene`, and
**never throws and never returns nil**. A missing or corrupt descriptor falls
back to `NexusScene.default(for:)` with a diagnostic.

That fallback is deliberate: a scene file is an *optimisation over* hardcoded
defaults, not a dependency. Shipping a build that black-screens because one
JSON was left out of a target would be a worse failure than the one it
replaces.

Two details worth knowing:

- **PRQ is applied at load, not baked in.** Descriptors stay static and
  cacheable; the athlete's readiness stays live.
- **A descriptor filed under the wrong mode is rejected**, not rendered — it
  would otherwise present as "the wrong game loaded," which the type system
  cannot catch.
- `preflight()` reports which modes are *not* running from a descriptor. Call
  it at startup: every mode works via the fallback, so a descriptor that never
  made it into the target is otherwise **silently** invisible until someone
  wonders why editing the JSON changes nothing.

### 2. All 20 descriptors — **generated, not written**

`tools/nexus_scenegen/` encodes the real Swift types. Hand-writing is exactly
what produced the undecodable file, so it is no longer possible: the generator
round-trips every descriptor as it writes it, and it stops compiling if the
model changes.

Entities are mode-appropriate rather than uniform — 3v3 gets a full six-body
court with both hoops; golf gets a ball, a hole trigger and no opponent;
karate gets ring-out triggers; `market_browse` gets **a camera and nothing
else**, because the Creator Market is a browsing surface with no avatar.

```bash
bash tools/nexus_scenes.sh --write   # regenerate
bash tools/nexus_scenes.sh           # verify all 20 load
```

### 3. Proof, by running the real loader

```
loaded from descriptor: 20/20
```

Not "20 files parse." Each is loaded through `NexusSceneLoader` and asserted
to: decode, carry the right `gameModeId`, contain entities, contain a camera,
and have PRQ applied at load time.

**And the gate was proven to bite.** I reintroduced the exact original bug
into `golf.nexus.json`:

```
nexus_check.py → ERROR  golf.nexus.json: entity 'player_golf' has
                 transform.position as dict, but CGPoint decodes from a
                 [x, y] ARRAY.
nexus_scenes.sh → loaded from descriptor: 19/20
                  FAIL golf: typeMismatch(Swift.Array<Any> …)
```

The Python gate and the real Swift decoder agree on the same file for the same
reason — and the loader **fell back instead of crashing**, exactly as designed.

### 4. The gate got stricter because the code got more capable

In M70, missing descriptors were a **WARN** — nothing loaded them, so failing
the build would have been noise. `nexus_check.py` now detects whether a loader
exists and promotes the same conditions to **ERROR**. It also validates
descriptor *shape* (array positions, case-keyed components, mode match) in
pure Python, so CI catches the original bug class **without needing Swift**.

### 5. Two more couplings removed

`NexusScene.swift` imported SwiftUI and **never used it** — that single line
put the entire scene model, and anything touching it, out of reach of any
non-Apple check. Removed. Same failure mode as `GameModeId` in M71.

`swift_typecheck.sh` now also strips `import CoreGraphics`, because
swift-corelibs-foundation already provides `CGPoint`/`CGFloat` on Linux — only
the module *name* is Apple-only.

Coverage: **45 → 47 files**, now including the whole scene system.

---

## FILES

| File | Goes where |
|---|---|
| `files/swift/NexusSceneLoader.swift` | `FinalEvolutionLab/Models/` — NEW |
| `files/scenes/*.json` (20) | `FinalEvolutionLab/Resources/NexusScenes/` |
| `files/tools/nexus_scenes.sh` | repo `tools/` — NEW |
| `files/tools/nexus_scenegen/` | repo `tools/` — NEW (generator + verifier) |
| `files/tools/nexus_check.py` | repo `tools/` — REPLACES M71's |
| `files/tools/green_check.sh` | repo `tools/` — REPLACES M71's |
| `files/tools/swift_typecheck.sh` | repo `tools/` — REPLACES M71's |

Also applied: `NexusScene.swift` (SwiftUI import removed), `VenueRegistry` and
`NexusProject.json` updated to point at the bundled directory, and the
undecodable `NexusStarter/.../basketball_h2h.nexus.json` **deleted** — replaced
by a README explaining why, since keeping a duplicate is how the schemas
drifted apart in the first place.

## ACCEPTANCE

1. `bash tools/nexus_scenes.sh` → **20/20 load from descriptor**.
2. `python3 tools/nexus_check.py` → **0 errors**.
3. `bash tools/green_check.sh --nexus` → **7 passed, 0 failed, 2 skipped**.
4. `bash tools/swift_typecheck.sh` → 47 files, no code defects.
5. On device: `NexusSceneLoader.preflight()` logs **nothing** — every mode
   running from its descriptor. Anything it prints is a bundling problem.

## WHAT IS STILL NOT DONE — the honest ledger

"Finished" above means **the Nexus scene architecture is complete and
verified**. It does not mean the product is shipped. Still open, unchanged by
this batch:

- **`NexusSceneView` does not consume the loader yet.** The descriptors load
  and validate; wiring the renderer to call
  `NexusSceneLoader.scene(for:prq:)` instead of `NexusScene.default(for:)` is
  a one-line change per call site, but it lives in the SwiftUI layer that
  cannot be verified here, so I did not make it blind. **This is the next
  step, and it is small.**
- **The iOS app has still never been compiled.** 114 UI-layer files need
  macOS + Xcode **16.3+** (see M71 — Swift 6.1 floor).
- **Entity layouts are principled, not playtested.** Spawn positions and
  trigger radii are sensible defaults derived from the venue registry; they
  need a real device pass to become *good*.
- **FEL (the Babylon web app) is a separate product** and is unaffected —
  M69 remains its current state.
