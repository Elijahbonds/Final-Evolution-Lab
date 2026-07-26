# M70 — NEXUS AUDIT: three build breakers, and the gate that finds them

This batch is **repo-side** (Swift, Xcode project, tools). Nothing here goes
into the Babylon app in Abacus.

---

## FIRST: WHAT "NEXUS" ACTUALLY IS

Two things were being conflated, so this is worth stating plainly.

**`nexusllm.abacusai.app` is not a separate product.** It serves the same
build as `finalevolution.abacusai.app` — same `<title>`, same landing markup.
It is a domain alias. Nothing to audit there that M69 did not already cover.

**Nexus is the native Swift engine in this repo.** `NexusProject.json` is
explicit: *"Replaces UE5 embedded runtime."* That is the real audit surface,
and it is the one thing in this project that **nothing has ever compiled** —
the build needs macOS + Xcode, so `green_check.sh` has honestly skipped it
since M68.

A skip was the right call. But "we cannot compile it" is not the same as
"we can learn nothing about it." Everything below was found on Linux, in
under a second, without a compiler — and every one of them breaks
`xcodebuild`.

---

## THE AUDIT

### ⚠️ 0. The size of Nexus was being reported ~9× too large

`green_check.sh` said **"Swift/Xcode build (1425 sources)"**, and I repeated
that figure in the M68 and M69 READMEs as *"the single biggest unverified
surface in Nexus."*

It was wrong. `find . -name '*.swift'` counts `.claude/worktrees/` — **1266
files across a dozen abandoned agent worktrees** (45 MB, gitignored, not
product code). The real Nexus surface is **159 files**.

Fixed to count product directories only. A number in a status report that is
off by 9× is a small lie that makes the honest parts of the report harder to
trust.

### 1. `FootballGameView.swift` cannot compile — one extra `}`

A brace-balance sweep of all 159 files found exactly one broken file: it ends
at depth **−1**.

Finding *which* brace was wrong took real work, because a naive count says
"delete any one closer in this range and it balances." Two candidates
survived counting; the tie was broken by what the code would **mean**:

- Deleting **1897** balances the file and even leaves every closer in the
  file correctly indented — but it makes line 1903 chain
  `.padding(.bottom, 40)` onto an `if` statement, which is not valid Swift.
- Deleting **1905** is the real fix. The intent is plainly:

  ```swift
  private var routeSelectPanel: some View {
      VStack(spacing: 0) {
          …
      }
      .ignoresSafeArea(edges: .bottom)
  }
  ```

  The stray closer ended the property one line early, orphaning
  `.ignoresSafeArea` at member level and leaving line 1907 to close the
  **struct** instead. Everything after it — 89 members — was parsed at top
  level while still indented as struct members.

Indentation actively pointed at the wrong answer here, because that block is
over-indented by one level from line 1888 onward. Worth knowing before
trusting a formatter on this file.

**Fix: delete line 1905.** All 159 files now balance.

### 2. A Swift package is nested inside the app's synchronized folder

`FinalEvolutionLab/Generated/SocialDataConnect/SocialDataConnect/` is
declared as an `XCLocalSwiftPackageReference` **and** sits inside the
`FinalEvolutionLab` `PBXFileSystemSynchronizedRootGroup`, which had **no
exception set**.

Xcode 16 synchronized groups compile *every* `.swift` under the folder. So:

- **`Package.swift` is compiled as app source.** It does
  `import PackageDescription` — a module that exists only in the SwiftPM
  manifest environment. Hard failure.
- **The package's `Sources/` are compiled twice** — once inside the
  `SocialDataConnect` module, once loose in the app target — while the app
  also does `import SocialDataConnect`. Duplicate declarations of
  `SocialClient`, `Post`, `User`, and friends.

**Fix:** added a `PBXFileSystemSynchronizedBuildFileExceptionSet` excluding
`Generated/SocialDataConnect` from the app target.

### 3. `import FirebaseDataConnect` with no such product linked

Five compiled files import it. The products linked to any target were
`FirebaseAuth`, `FirebaseCore`, `FirebaseCrashlytics`, `FirebaseFirestore`,
`SocialDataConnect` — **no `FirebaseDataConnect`**.

It is a dependency *of the local package*, and **Swift does not re-export a
dependency's dependencies**. Fix #2 removes three of the five offenders (they
belong to the package, which declares the dependency correctly), leaving two
genuine app files: `CommunityFeedView.swift` and `TrainingLabSocialBridge.swift`.

Both legitimately talk to Data Connect through the generated connector, so
the right fix is to link the product rather than delete the import:

**Fix:** added `data-connect-ios-sdk` (`from 11.11.0`, matching the local
package manifest) as a remote package reference, and `FirebaseDataConnect`
as a product dependency of the app target.

### 4. The declared Nexus architecture is not the built one — WARN

`NexusProject.json` states: *"All scenes are JSON-defined NexusScene
descriptors rendered by NexusSceneView via SwiftUI Canvas."*

**No Swift file references `NexusStarter` or any `.nexus.json`.** The JSONs
are not in the Xcode project and are never bundled. Scenes are actually built
in code by `NexusScene.default(for: modeId)`. The descriptors are orphaned
data.

Relatedly, the venue registry maps 20 modes to scene files and **18 of them
do not exist** (only `basketball_h2h.nexus.json` is present;
`market_browse` is legitimately `null`).

This is reported as a **WARN, not an ERROR**, and the distinction is the
point: nothing reads these files, so nothing breaks today. It becomes an
ERROR the day a loader is wired — which is exactly when the message stops
being noise and starts being the bug report. Either wire the loader and
author the 18 scenes, or stop describing the architecture as data-driven.

### ✅ What is genuinely healthy

- **Registry sync is perfect.** All 20 mode IDs match exactly between the
  Nexus venue registry and `backend/FEL_ModeManager.production.json` — zero
  drift in either direction. Given how easily two registries diverge, this is
  worth protecting, so the gate now checks it.
- **All Nexus JSON parses.**
- **No secrets tracked.** Only `GoogleService-Info.example.plist`, and every
  value in it is `REPLACE_ME`. `smoke-state.json`, `smoke-shots/` and
  `smoke-report.json` are present on disk and correctly gitignored.
- **`ShotType` / `SwipeDir` duplicates are fine** — both `private`, so
  file-scoped. Flagged then cleared; noting it so nobody "fixes" them.
- **`infra/native_ios/FELNativeSwiftBridge.swift`** duplicates a type in
  `Services/`, but `infra/` is outside every synchronized group, so it is not
  compiled. A stale parallel copy and a maintenance hazard — not a build
  break.

---

## `tools/nexus_check.py` — so this cannot silently rot again

```
python3 tools/nexus_check.py          # human
python3 tools/nexus_check.py --json   # for nexus_agent.mjs
```

Four checks, each written because it caught a real defect above:

| Check | Catches |
|---|---|
| brace balance | files that cannot compile (#1) |
| SPM nesting | a package manifest compiled as app source (#2) |
| imports vs linked products | an import with no product behind it (#3) |
| registry ↔ disk ↔ backend | orphaned descriptors, mode drift (#4) |

The brace tokenizer is hand-written because counting `{` and `}` is wrong on
this codebase. It has to understand `\(…)` **interpolation**, which re-enters
code and can nest strings — `FootballGameView.swift` contains
`Text("& \(x >= 90 ? "GOAL" : "\(y)")")`, and a tokenizer that treats
interpolation as opaque string content mis-tracks state from that line on.

Wired into `green_check.sh` as a **PASS/FAIL gate** that runs before the
skipped Xcode build.

## FILES

| File | Goes where |
|---|---|
| `files/tools/nexus_check.py` | repo `tools/` — NEW |
| `files/tools/green_check.sh` | repo `tools/` — REPLACES M68's |
| `files/patches/nexus-build-fixes.patch` | already applied; included for review |

## ACCEPTANCE

1. `python3 tools/nexus_check.py` → **0 errors**, 2 warnings (the orphaned
   descriptors).
2. `bash tools/green_check.sh --nexus` → Swift/Nexus static gate **PASS**;
   Xcode build still honestly **SKIP**, now reporting **159** sources.
3. `xcodebuild -scheme FinalEvolutionLab build` on the Mac mini **gets
   further than before** — see the caveat below.

## ⚠️ THE HONEST LIMIT ON #2 AND #3

The Swift brace fix is verified: all 159 files balance, and the resulting
structure puts all 89 struct members back at member scope.

**The two `project.pbxproj` fixes are not compile-verified, because nothing
here can open an Xcode project.** What I did verify: the file's braces and
parens still balance, every referenced UUID resolves (the single unresolved
ID is the root group and predates this change), and the new objects match the
exact shape of the existing ones. That is structural confidence, not a green
build.

Expect the first real `xcodebuild` run to surface more — **nothing has ever
type-checked these 159 files.** Three build breakers were sitting in plain
sight without a compiler; there will be others that need one. This batch
removes the ones that are findable from here, and gives you a gate so the
next ones get caught on push instead of on a Mac.
