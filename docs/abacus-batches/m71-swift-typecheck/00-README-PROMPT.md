# M71 — YES: Nexus now actually compiles here (45 of 159 files), and it found a real bug

Repo-side batch. Nothing goes into Abacus.

---

## THE SHORT ANSWER

**Partly, and it was worth doing.** The iOS app genuinely cannot be *built*
here — it is an iOS app, and 74% of its files import SwiftUI, UIKit or
Firebase, none of which exist off-Apple. No amount of effort produces a
linkable `.app` on Linux.

But `AGENTS.md` said *"Cannot be built in a Cloud Agent VM"*, and that had
been read as *"nothing about it can be verified anywhere but a Mac."* Those
are not the same claim, and the difference turned out to be worth **45
files**.

I installed the Swift 6.0.3 Linux toolchain and type-checked the portable
core with a real compiler:

```
Swift version 6.0.3 (swift-6.0.3-RELEASE) · Target: x86_64-unknown-linux-gnu
type-checking 45 portable file(s) + shims
→ No code defects.
```

That set is not an arbitrary 28%. It is **the entire physics / rules / engine
core**: `ArcadePhysics`, `MatrixPhysicsEngine`, `HelpDefense3v3`,
`AvatarStateMachine`, `ShardEconomy`, `Matchmaking`, `DynamicDifficulty`,
`NexusRenderer`, `BiomechanicsAudit`. The part that is left needing a Mac is
the UI layer.

---

## WHAT COMPILING FOUND THAT STATIC ANALYSIS COULD NOT

### 1. 🐞 A real compile error: non-exhaustive `switch` over every game mode

```
ArcadePhysics.swift:241:9: error: switch must be exhaustive
  note: add missing case: '.basketballIRL'
  note: add missing case: '.whoSceneIt'
  note: add missing case: '.courtCarnival'
  note: add missing case: '.marketBrowse'
```

`GamePhysicsConfig.forMode(_:prq:audit:)` handles 16 of 20 modes. Four modes
were added to `GameModeId` — and to both registries, which M70 verified are
in perfect sync — but never to the physics table. **The iOS build fails on
this.** M70's static gate could not see it; only a type-checker can.

Fixed with the grouping each mode actually belongs to:

| Mode | Profile | Why |
|---|---|---|
| `.basketballIRL`, `.courtCarnival` | basketball | same court, same movement model |
| `.whoSceneIt` | gymnastics/brainBrawl | seated recall game, low locomotion |
| `.marketBrowse` | **all zeroes** | the Creator Market is a browsing surface with no avatar; an inert config is the correct answer, not a scaled athletic one |

### 2. ⚠️ The project requires **Xcode 16.3 / Swift 6.1** — documented nowhere

`AGENTS.md` said **"Xcode 15+"**. That is wrong twice:

- **147 declarations across 39 files** apply `nonisolated` to a *type*
  (`nonisolated struct`, `nonisolated enum`). That is **SE-0449, Swift 6.1**.
  A Swift 6.0 compiler rejects every one — confirmed with a minimal repro, not
  inferred:
  ```
  $ swiftc -typecheck <<< 'nonisolated struct A { let x = 1 }'
  error: 'nonisolated' modifier cannot be applied to this declaration
  ```
  **This code is correct. Do not "fix" the 147 declarations** — the toolchain
  is the thing that has to move.
- `project.pbxproj` is `objectVersion = 77` with
  `PBXFileSystemSynchronizedRootGroup`. **Xcode 15 cannot open this project
  at all.**

So a Mac mini on Xcode 16.0–16.2 fails with 147 errors that look like code
rot and are not. `AGENTS.md` is corrected, and `nexus_check.py` now reports
both floors **without needing a compiler**.

Note the distinction the check makes: `nonisolated` on a **member** (indented)
has been legal since Swift 5.5. Only the **column-0, type-level** form is
6.1+. Matching loosely would have produced a nonsense number.

### 3. The model layer was needlessly coupled to SwiftUI

`ArcadePhysics` could not type-check because `GameModeId` lived in
`GameMode.swift` — and `GameMode` needs SwiftUI for `accentColor: Color`.
A plain `String` enum was dragging the physics core into the UI layer purely
by file placement.

Extracted to `Models/GameModeId.swift`. Coverage went 44 → 45 files, and
**that is what exposed bug #1** — the `switch` error was invisible while
`GameModeId` itself could not resolve. Only 5 of 38 `Models/` files import
SwiftUI, so this was the outlier, not the pattern.

Xcode needs no project edit: `FinalEvolutionLab` is a synchronized root
group, so new files are picked up automatically.

---

## `tools/swift_typecheck.sh`

```
bash tools/swift_typecheck.sh              # use an installed toolchain
bash tools/swift_typecheck.sh --install    # fetch Swift (~750 MB) if missing
bash tools/swift_typecheck.sh --list       # show what would be checked
```

Runs on any Ubuntu runner, so this is CI-able **today** — no Mac required for
the core.

Two small Linux shims in `tools/swift-shims/` (`OSLog`, `QuartzCore`) are
what lift coverage from 38 files to 45. They are surface-compatible no-ops,
**type-check only, never shipped**.

**A missing toolchain is a SKIP, never a failure** — the same rule the rest
of this toolchain follows.

It also separates **TOOLCHAIN** findings from **FAIL** findings, because
telling someone to fix 147 correct declarations would be actively harmful.

> While writing it I hit a counting bug worth flagging: `N_ISO` matched the
> bare message, which also appears on the compiler's caret/context line, so it
> exceeded `N_ERR`, drove `N_OTHER` negative, and **silently swallowed 3 real
> errors**. Both counts are now anchored on `": error:"`. It is a small bug
> with exactly the shape of the ones this whole toolchain exists to catch — a
> gate reporting clean because it miscounted.

## FILES

| File | Goes where |
|---|---|
| `files/tools/swift_typecheck.sh` | repo `tools/` — NEW |
| `files/tools/nexus_check.py` | repo `tools/` — REPLACES M70's (adds toolchain floor) |
| `files/shims/OSLog.swift` | repo `tools/swift-shims/` |
| `files/shims/QuartzCore.swift` | repo `tools/swift-shims/` |

Repo edits already applied: `ArcadePhysics.swift` (the 4 missing cases),
`GameModeId.swift` (extracted), `GameMode.swift`, `AGENTS.md`.

## ACCEPTANCE

1. `bash tools/swift_typecheck.sh` → **45 files, no code defects**; the only
   output is the Swift 6.1 toolchain note.
2. `python3 tools/nexus_check.py` → 0 errors; warns about both toolchain
   floors and the orphaned Nexus descriptors.
3. On a Mac with **Xcode 16.3+**, `xcodebuild -scheme FinalEvolutionLab build`
   no longer fails on `GamePhysicsConfig.forMode`.

## THE HONEST LIMIT

This is a **type-check of a subset**. It does not link, does not run, does not
touch the 114 UI-layer files, and is not a substitute for `xcodebuild`.

What changed is the size of the unknown. Before: 159 files, none ever
compiled. Now: 45 compile clean, and the remaining 114 are specifically the
SwiftUI/UIKit/Firebase layer. Expect the first real `xcodebuild` run to
surface more — but it will be UI-layer work, and it will not be the physics
core.
