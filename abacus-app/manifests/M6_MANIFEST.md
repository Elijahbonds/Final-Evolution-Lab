# M6 — Studio To Spec · MANIFEST

**Milestone:** 6 of 6  
**Track:** Studio To Spec (full) + Game Parity roll-out  
**Date:** 2026-07-15  
**Status:** COMPLETE ✓

---

## What Shipped

### 1. Game-parity roll-out — 18+ modes wired to `SessionRecorder`

Every remaining 2D canvas game now mirrors its **existing** hit / miss / dodge / chain
events into a `SessionRecorder` (from `lib/game-systems.ts`) and forwards
`tallies` + `maxCombo` at each `onEnd` site. This is **purely additive** — no scoring
number, timing window, spawn value, or difficulty tier was touched. All gameplay-feel
constants remain `// TUNE(elijah)`.

**Combo games:** skateboard, snowboard, surf, golf, gymnastics, karate, rail-grind, glitch-boss  
**Score / hit-miss games:** baseball, soccer, brain-brawl, training, big-air, tennis,
tiebreak, sprint, three-point, who-scene-it, karate-versus, one-v-one, three-v-three  
*(dunk-game was the M5 template.)*

### 2. Tally persistence pipeline

| File | Change |
|---|---|
| `lib/game-systems.ts` | Re-exports `SessionTallies`; adds pure `sanitizeTallies()` helper. |
| `components/games/game-shell.tsx` | `GameResult` gains optional `tallies` + `maxCombo`; forwarded to POST `/api/sessions`. |
| `app/api/sessions/route.ts` | Reads + sanitizes optional tallies via `sanitizeTallies()`; persists them. |
| `prisma/schema.prisma` | `GameSession` gains additive `hits/misses/dodges/combos/maxCombo Int @default(0)`. |

### 3. M6 compliance gate — `lib/cell-compliance.ts`

**Provider-level gate (Phase 1 — prior delivery):**
- `PROVIDER_JURISDICTION` — coarse residency map (all 4 providers = US). `// TUNE(elijah)`
- `evaluateProvider(provider, policy?)` → structured `ComplianceDecision`
- `assertProviderAllowed(provider, policy?)` → throws `ComplianceError`
- Default = allow-all (backward compatible).
- Wired into `lib/cell-providers.ts` `callModel` as the first statement.

**Content-level denylist (Phase 2 — this delivery):**
Per **NEXUS_COST_DOCTRINE.md** and **MODEL_ROUTING_PROTOCOL.md**, Tencent-Cloud-hosted
models must never receive Neuromechanic scoring logic, biometric/likeness/mocap data,
or EU AI Act disclosure work.
- `CONTENT_RESTRICTED_PROVIDERS` — set of providers triggering content checks (`// TUNE(elijah)`).
- `DENYLIST_KEYWORDS` — 14 keywords across 3 categories; case-insensitive substring match.
- `evaluateContent(provider, body)` → `ContentDecision` (no throw).
- `assertContentAllowed(provider, body)` → throws `ComplianceError` when blocked.
- Wired into `cell-build.ts` `runLLM()` — evaluated BEFORE the provider network call.

### 4. Self-verifying builds (Phase 3)

**AcceptanceCheck schema** (`lib/cell-engine.ts`):
- New `AcceptanceCheck` interface: `id`, `description`, `type` (`html_contains` / `html_regex` / `no_console_error_pattern` / `file_exists`), `value`.
- `BuildPlan.acceptanceChecks?: AcceptanceCheck[]` — 3–8 machine-checkable criteria emitted by the architect. A build is "complete" only when ALL pass.
- Architect system prompt updated to emit acceptance checks in every plan.

**Bundle validator** (`lib/cell-files.ts`):
- `runAcceptanceCheck()` — evaluates a single check against bundle HTML + file tree.
- `validateBundle()` — runs 3 built-in structural checks (DOCTYPE, `<script>`, `undefined.xxx` pattern) + all architect-emitted checks. Returns `ValidationReport { passed, total, failures, all }`.

**Self-verifying repair loop** (`lib/cell-build.ts`):
- After the critic pass, `runBuild()` calls `validateBundle()` against the assembled HTML.
- If any checks fail, it runs ≤2 repair iterations (TUNE(elijah)): sends the failure list to the critic model, applies emitted file ops, re-validates.
- `BuildResult` now includes `validation?: ValidationReport` and `repairAttempts: number`.
- Final project status is `ready` only when ALL checks pass; otherwise `needs-attention` with the failure list persisted in artifacts JSON.

**Compliance threading:**
- `BuildCtx.compliance?: CompliancePolicy` forwarded to every `callModel` invocation.
- Content denylist check in `runLLM()` before each model call.

---

## Tests & Evidence

**`scripts/m6-tests.ts`** — 21/21:
- SessionRecorder counting, `sanitizeTallies` edge cases, provider-level compliance gate.

**`scripts/m6-phase3-tests.ts`** — 26/26:
- AcceptanceCheck types (html_contains ✓/✗, html_regex ✓/✗/invalid, no_console_error_pattern ✓/✗, file_exists ✓/✗).
- `validateBundle` composite (passing + failing architect checks, builtin detections: missing DOCTYPE, missing script, undefined deref, architect-only vs builtins-only).
- Content denylist (non-restricted pass, Tencent restricted, neuromechanic/biometricmirror/EU-AI-Act blocks, clean pass, throw/no-throw, keyword categories).
- BuildPlan backward compat (with/without acceptanceChecks).

**Full regression — all suites green:**

| Suite | Result |
|---|---|
| `scripts/m2-tests.ts` | 9 / 9 |
| `scripts/m3-tests.ts` | 11 / 11 |
| `scripts/m4-tests.ts` | 13 / 13 |
| `scripts/m5-game-smoke.ts` | 21 / 21 |
| `scripts/m6-tests.ts` | 21 / 21 |
| `scripts/m6-phase3-tests.ts` | 26 / 26 |

`yarn tsc --noEmit` clean · production build 37/37 pages · auth smoke green.

---

## Export

- `exports/fel-nexus-M6-gameparity.zip` — all CELL/compliance modules, game components, schema, test scripts.
- `exports/M6_MANIFEST.md` / `.pdf` / `.docx`

---

## What’s Next

- **Phase 4 (game engine capabilities):** Curated runtime library the builder targets, ASSETS panel.
- **Phase 5 (reliability at scale):** Resumable background jobs, version snapshots, queue coalescing.
- Elijah to tune `// TUNE(elijah)` constants now that tallies stream end-to-end.
- Surface residency selector in Studio spec UI populating `CompliancePolicy`.
- Run the 3-model routing golden-set eval (MODEL_ROUTING_PROTOCOL.md) when model candidates are onboarded.

## Open Questions

- EU-resident provider endpoints, or US-only for launch?
- Compliance policy scope: per-spec, per-project, or per-workspace?
- Tencent HY3 self-hosted open-weights path for denylisted work — timeline?
