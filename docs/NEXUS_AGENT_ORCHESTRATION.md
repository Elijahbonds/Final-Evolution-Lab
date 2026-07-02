# NEXUS Agent Orchestration — PM & Senior Advisor

**Canonical repo:** `/Users/elijahbonds/Final-Evolution-Lab`  
**Mirror (reference only):** `~/Documents/rork-final-evolution-lab` — may lag; never treat as ship source of truth (V-016).

**Related:** `docs/NEXUS_AGENT_FLEET_STATUS.md` · `Config/nexus_agent_roles.json` · `docs/NEXUS_VISION_ALIGNMENT.md` · `NEXUS_DELIVERY_MATRIX.md` · `NEXUS_QUALITY_BAR.md`

---

## Purpose

Two **persistent coordinator roles** sit above specialized subagents. They do not implement features directly; they **prioritize, delegate, veto off-scope work, and maintain fleet visibility** for the NEXUS-only Final Evolution Lab retail ship.

| Role | Cursor invocation | Primary output |
|------|-------------------|----------------|
| **Project Manager (PM)** | Parent coordinator runs PM checklist after every subagent completion | Updated priority queue, retasks, `NEXUS_AGENT_FLEET_STATUS.md`, `## Agents working` footer |
| **Senior Advisor** | Parent coordinator runs Advisor review before spawning retasks or approving handoffs | Veto / redirect when work violates NEXUS-only architecture or quality bar |

Machine-readable role definitions: `Config/nexus_agent_roles.json`.

---

## Project Manager (PM)

### Mandate

- Own **fleet status** and the **priority queue** (P0–P3).
- **Delegate** work to the right specialty (see Delegation matrix).
- **Retask** when blockers clear, drift IDs remain open, or user priorities shift.
- Maintain **`docs/NEXUS_AGENT_FLEET_STATUS.md`** after each subagent completion.
- End every coordinator reply with the **`## Agents working`** table (see template).

### Priority queue (authoritative sources)

Pull priorities from:

1. **`docs/NEXUS_VISION_ALIGNMENT.md`** — drift register V-001..V-016 and recommended retasks table.
2. **`NEXUS_DELIVERY_MATRIX.md`** — Phase 8 TestFlight blockers, Spec v1 DoD gaps.

**Current PM top stack (2026-06-19):**

| Pri | Work item | Drift / matrix | Specialty |
|:---:|-----------|----------------|-----------|
| **P0** | Real `GoogleService-Info.plist` + `./scripts/archive-ios-testflight.sh --export` → signed IPA | V-003, Phase 8 | `ios_ship` |
| **P1** | Registry honesty: align `ArenaReleaseState` with `nexus_validate_production_modes.sh`; document/rename `productionMapPath` | V-004, V-005 | `registry` |
| **P1** | Venue assets bundle verified on device (manifest + `.nexusmesh.json` resolution) | Delivery matrix #3 (fixed in tree; device proof open) | `assets`, `ios_ship` |
| **P1** | Legacy manager retirement audit — no Release-path dispatch to `UnrealManager` / `UnityManager` | V-006, V-007 (fixed); grep for regressions | `ios_ship`, `vision_guardian` |
| **P2** | Live Firebase session receipt POST (Spec v1 DoD #4) | V-012 | `backend` |
| **P2** | Metal device dunk + Instruments 60 FPS | V-013 | `renderer`, `ios_ship` |
| **P2** | Fix `NEXUS_GAMEPLAY_UX_BAR.md` UE registry row | V-011 | `docs` |
| **P3** | Mirror repo sync (`rork-final-evolution-lab`) | V-016 | `docs` |

**P1 preview labels (V-008):** mostly **DONE** — PM should not retask unless new Swift surfaces ship without `FELPreviewLabel`.

### Retask rules

1. **Close the loop:** Every completed subagent handoff → PM updates fleet status → PM proposes 0–3 retasks ranked by P0–P3.
2. **One P0 at a time:** Do not spawn parallel P0 iOS archive work unless explicitly user-requested; serialize signing/plist tasks.
3. **Build evidence required:** No retask marked "unblocked" without command output or test name cited in handoff.
4. **Drift ID linkage:** Every retask must reference at least one V-00x ID or delivery-matrix row.
5. **Stale agent kill:** If an in-flight task targets UE ship, mirror-only edits without canonical port, or lacks canonical path prefix → PM cancels and rewrites prompt.
6. **Resume vs spawn:**
   - **Resume** when: same drift ID, same file scope, prior agent has context (<24h), and handoff says "partial" or "blocked on X" now resolved.
   - **Spawn** when: new specialty, new drift ID, conflicting scope, or prior agent completed with clean handoff.
7. **User blockers:** Items needing credentials (Firebase plist, Apple signing, App Store Connect) → `Blocked (needs user)` section, not silent queue.

### PM checklist (every subagent completion)

Run in order; parent coordinator executes this mentally or via `nexus-pm-advisor` skill:

- [ ] Parse subagent **handoff** (required format below).
- [ ] Run **Senior Advisor veto** pass on proposed follow-ups.
- [ ] Update **`docs/NEXUS_AGENT_FLEET_STATUS.md`**: move task to Completed (keep last 10), remove from In flight, adjust PM snapshot top 3.
- [ ] Mark drift IDs **FIXED** / **OPEN** in handoff summary (PM does not edit `NEXUS_VISION_ALIGNMENT.md` unless user asked — note deltas for `vision_guardian`).
- [ ] Queue **0–3 retasks** with priority, specialty, and entry prompt stub.
- [ ] If fleet has **idle specialties** (no in_flight row): prompt idle **brainstorm_assist** or assign **`[support]`** assist to in-flight primaries (see **Idle agent brainstorm**).
- [ ] Emit coordinator reply ending with **`## Agents working`** table.

---

## Senior Advisor

### Mandate

- Hold **architecture truth:** NEXUS-only production ship (`NEXUS_ONLY_PIVOT.md`, `SHIPPING_ARCHITECTURE.md`).
- Enforce **quality bar:** `NEXUS_QUALITY_BAR.md` — no "shipped" claims without signed IPA + device proof where applicable.
- Enforce **vision alignment:** `docs/NEXUS_VISION_ALIGNMENT.md` — honest preview labeling, registry honesty, agent control plane scope.
- **Veto bad retasks** before PM spawns subagents.

### Veto list (automatic redirect)

| Violation | Advisor action |
|-----------|----------------|
| UE / Unity as **production ship** target | **VETO** — redirect to NEXUS iOS + C++20 path; cite `NEXUS_ONLY_PIVOT.md` |
| Retask to run `fel_ue5_ios_shipping_package.sh` for retail | **VETO** — archived; use `./scripts/archive-ios-testflight.sh` |
| Swift UI surface without `FELPreviewLabel` where matrix marks preview/stub | **VETO** — redirect to `ios_ship` with explicit view list |
| Active Release dispatch to `UnrealManager` / `UnityManager` (ungated) | **VETO** — redirect to NEXUS bridge; legacy only under `NEXUS_LEGACY` |
| Claim TestFlight live from `--dry-run` only | **VETO** — require real plist + `--export` evidence |
| Edit mirror repo only without canonical port plan | **VETO** — canonical path required; mirror sync is P3/V-016 |
| Extend `UnrealIntegration/` / `UnrealStarter/` for retail features | **VETO** — reference archive only |
| Remove whitelisted agent tools / arbitrary shell from MCP | **VETO** — cite `Config/nexus_cursor_tool_registry.json` |

### Advisor approval signals

Handoff **APPROVED** when:

- Changes under `/Users/elijahbonds/Final-Evolution-Lab` (or explicit canonical paths).
- Build/test commands from delivery matrix re-run and cited.
- Preview labels present on touched Swift marketing/gameplay stubs.
- No new OPEN P0/P1 drift introduced.

Handoff **NEEDS REVISION** when any veto triggers; PM must rewrite retask prompt before spawn.

---

## Delegation matrix

Task type → specialty → entry prompt template. Always prefix prompts with canonical repo path.

| Task type | Specialty `id` | When to use | Entry prompt template |
|-----------|----------------|-------------|------------------------|
| Engine/gameplay tests, mode sims, C++ gameplay | `gameplay_tester` | Failing ctest, mode validate-only gaps, physics/registry logic | `At /Users/elijahbonds/Final-Evolution-Lab fix [test/mode]. Run ./scripts/nexus_build_gate.sh and ./scripts/nexus_validate_production_modes.sh. Return handoff. Drift: [V-00x].` |
| Vision/drift audit, NEXUS-only enforcement | `vision_guardian` | Doc drift, legacy path grep, alignment score | `At /Users/elijahbonds/Final-Evolution-Lab audit [area] against docs/NEXUS_VISION_ALIGNMENT.md. List drift IDs opened/closed. Do not extend UE ship.` |
| iOS compile, archive, Swift bridge, preview labels | `ios_ship` | xcodebuild, TestFlight, `FELPreviewLabel`, `NexusGameplayBridge` | `At /Users/elijahbonds/Final-Evolution-Lab [task]. Run ./scripts/build-nexus-ios.sh and xcodebuild sim build. Drift: [V-003/V-008/...]. NEXUS-only.` |
| CI/build failures, ctest regressions | `debugging` | Red gates, linker errors, flaky tests | `At /Users/elijahbonds/Final-Evolution-Lab diagnose [failure]. Capture failing command output. Fix minimal diff. Re-run gate.` |
| Compile errors, missing symbols, header paths | `error_editor` | Single-file or narrow compile fix | `At /Users/elijahbonds/Final-Evolution-Lab fix compile error in [file]. Minimal change. Re-run [specific test/build].` |
| `arena_mode_registry`, production mode validation | `registry` | V-004, V-005, validate script skew | `At /Users/elijahbonds/Final-Evolution-Lab align arena_mode_registry with nexus_validate_production_modes.sh. Document productionMapPath legacy alias. Drift: V-004, V-005.` |
| `.nexusmesh.json`, manifests, bundle copy | `assets` | Venue bundle, mesh sidecars, import pipeline | `At /Users/elijahbonds/Final-Evolution-Lab verify NEXUS venue assets in app bundle and NEXUS_RESOURCE_ROOT resolution.` |
| Firebase receipts, session POST, Supabase | `backend` | V-012, receipt drain, auth POST | `At /Users/elijahbonds/Final-Evolution-Lab wire live Firebase session receipt POST per NEXUS_BACKEND_CONTRACT.md. Drift: V-012.` |
| Metal embed, renderer, FPS proof | `renderer` | V-013, Metal PBR, Instruments | `At /Users/elijahbonds/Final-Evolution-Lab improve Metal embed path; document device validation steps. Drift: V-013.` |
| AGENTS.md, matrix docs, mirror sync | `docs` | V-011, V-016, orchestration updates | `At /Users/elijahbonds/Final-Evolution-Lab update [doc] for NEXUS-only truth. Canonical path only.` |

**Coordinator roles (not delegated as implementation):**

| Role | `id` | Delegates to |
|------|------|--------------|
| Project Manager | `project_manager` | all specialties + support agents (spawn/resume) |
| Senior Advisor | `senior_advisor` | `vision_guardian`, `docs` (audit-only) |

**Support agents (parallel helpers — assist only, no vertical ownership):**

| Role | `id` | Assists | Primary output |
|------|------|---------|----------------|
| Support — Build & Verify | `support_build_verify` | `ios_ship`, `registry`, `assets`, `gameplay_tester`, `debugging`, `error_editor` | Commands run, log excerpts, PASS/FAIL verdict |
| Support — Docs & Drift | `support_docs_drift` | `vision_guardian`, `project_manager`, `senior_advisor`, `docs` | Drift ID labels, fleet/matrix doc deltas, optional mirror port |

---

## Support agents

Support agents are **optional parallel helpers**. Primary specialty agents **own** the vertical (fix, ship, audit). Support agents **never** retask the fleet, veto Advisor decisions, or claim a drift ID fixed without the primary agent's evidence.

### When a primary agent should spawn a helper

| Primary specialty | Spawn `support_build_verify` when… | Spawn `support_docs_drift` when… |
|-------------------|-------------------------------------|----------------------------------|
| `ios_ship` | Sim/device build needed while primary edits Swift; re-verify archive prerequisites after plist drop | Fleet row or matrix Phase 8 status needs update after handoff |
| `registry` | Re-run `nexus_validate_production_modes.sh` after registry patch | Document V-004/V-005 row honestly in vision alignment |
| `assets` | Bundle inspection + mesh sidecar grep on `.app` | Delivery matrix venue row needs device-proof label |
| `gameplay_tester` | Parallel gate run while primary fixes ctest | N/A unless PM asks for matrix wording |
| `debugging` / `error_editor` | Re-run narrowed build after compile fix | N/A |
| `vision_guardian` | Optional gate sanity check during audit | Drift register edits + fleet `[support]` rows |
| `project_manager` | Batch verify before P0 retask spawn | Update `NEXUS_AGENT_FLEET_STATUS.md` after subagent flood |

**PM / parent coordinator:** tag support tasks in **`## Agents working`** and fleet **In flight** with **`[support]`** prefix in the Task column. Support rows do **not** consume P0 ownership — the primary specialty row stays the owner.

### Anti-patterns (duplicate ownership)

| Anti-pattern | Why wrong | Correct pattern |
|--------------|-----------|-----------------|
| Two agents both "own" V-003 archive | Split signing responsibility | `ios_ship` owns fix; `support_build_verify` runs `--dry-run` / sim build only |
| Support marks V-00x **FIXED** from green local gate alone | Missing device/signing evidence | Support returns PASS/FAIL; primary or `vision_guardian` updates drift register |
| Support implements registry or Swift fix "while here" | Steals vertical scope | Return FAIL + logs; retask `debugging` / `registry` / `ios_ship` |
| Parallel support + primary edit **same files** | Merge conflicts, duplicate diffs | Support reads only unless PM assigns doc-only scope |
| Support overrides Advisor **VETO** | Breaks NEXUS-only control plane | Escalate to PM; do not spawn retask |

### Example delegation prompts

**Primary → Build & Verify (parallel while primary codes):**

```text
At /Users/elijahbonds/Final-Evolution-Lab — support_build_verify assisting ios_ship.
Run ./scripts/build-nexus-ios.sh then xcodebuild -scheme FinalEvolutionLab -destination 'platform=iOS Simulator,name=iPhone 16' build.
Do not edit Swift. Return Support handoff with PASS/FAIL and last 30 lines on failure. Drift: V-003.
```

**Primary → Build & Verify (registry evidence):**

```text
At /Users/elijahbonds/Final-Evolution-Lab — support_build_verify assisting registry.
After registry agent lands patch, run ./scripts/nexus_validate_production_modes.sh and ./scripts/nexus_build_gate.sh.
Verdict only; do not change arena_mode_registry. Drift: V-004, V-005.
```

**PM → Docs & Drift (fleet update after handoff):**

```text
At /Users/elijahbonds/Final-Evolution-Lab — support_docs_drift assisting project_manager.
Ingest handoff from agent fd5afa8b; update docs/NEXUS_AGENT_FLEET_STATUS.md In flight → Completed.
Honest drift labels only; do not mark V-003 FIXED. Tag task [support] in fleet table.
```

**Vision guardian → Docs & Drift (drift register):**

```text
At /Users/elijahbonds/Final-Evolution-Lab — support_docs_drift assisting vision_guardian.
Update docs/NEXUS_VISION_ALIGNMENT.md recommended retasks table for V-006/V-007 grep evidence supplied below.
Do not change C++ or Swift. Senior Advisor labels stand — no FIXED without device proof.
```

**Skill shortcut:** activate `nexus-support-agents` (`~/.cursor/skills/nexus-support-agents/SKILL.md`) when spawning `[support]` parallel tasks.

---

## Gameplay + Quality unison

`gameplay_tester` and `quality_check` run as a **paired unison loop** when the build gate Phase 1 headless matrix is red or mode validation is in flux. They share session-scoped handoff files under `artifacts/coord/` — not fleet status; PM ingests after both agents report.

| Agent | Handoff file | Owns |
|-------|--------------|------|
| `gameplay_tester` | `artifacts/coord/gameplay_handoff.json` | C++ mode sim fixes, `nexus_gameplay_test`, `nexus_gameplay_regression.sh`, snowboarding/staging payload shape |
| `quality_check` | `artifacts/coord/quality_handoff.json` | Independent re-run of gate + validate scripts; flags FAIL items for gameplay to address |

### Unison protocol (each tranche)

1. **Gameplay** fixes failing tests or documents an honest blocker; runs `./scripts/nexus_gameplay_regression.sh` (or `ctest -R nexus_gameplay`) and `./scripts/nexus_validate_production_modes.sh`.
2. **Gameplay** writes `gameplay_handoff.json` with: `timestamp`, `tests_run[]`, `pass`/`fail`, `files_changed[]`, `blockers[]`, `next_quality_action`.
3. **Quality** reads `gameplay_handoff.json`, re-runs `./scripts/nexus_build_gate.sh` (headless ctest), and writes `quality_handoff.json` with independent PASS/FAIL and any regressions gameplay missed.
4. **Gameplay** reads `quality_handoff.json` if present — address every `FAIL` item quality flagged.
5. **Loop** until `./scripts/nexus_build_gate.sh` headless ctest is green **or** an honest blocker is documented in both handoffs (user credential, device-only, etc.).

**Exit criteria:** `nexus_build_gate PASS` + `nexus_validate_production_modes PASS (14 modes)` cited in both handoffs. Quality does not mark drift IDs FIXED; primary or `vision_guardian` owns drift register updates.

**Stale binary note:** Snowboarding `json.exception.type_error.305` often passes after `cmake --build build-headless --target nexus_gameplay_test` when source already uses object-first `merge_patch(stateJson())` — quality should fail stale-artifact reruns that skip rebuild.

---

## Idle agent brainstorm

When a specialty agent has **no in-flight task** for its vertical, the parent coordinator (or the agent itself on idle notification) triggers a **bounded brainstorm** instead of sitting idle. Idle agents **assist the project** by surfacing gaps and pairing opportunities — they do **not** spawn retasks or implement fixes without PM + Advisor approval.

### When triggered

| Condition | Example |
|-----------|---------|
| No **in_flight** row for agent specialty in fleet status | `backend` idle while P0 is `ios_ship` |
| Primary work **blocked** (user credential / dependency) | V-003 plist missing — `ios_ship` blocked; `renderer` idle |
| **Waiting** on another agent's handoff | `assets` waiting on `ios_ship` device build |
| Support task **complete with PASS** and no follow-up assigned | `support_build_verify` finished gate re-run; no new verify queued |

**Time box:** 15 minutes max — read fleet status, vision alignment, delivery matrix; produce one **`## Brainstorm handoff`** block.

### What idle agents do

1. Scan **`docs/NEXUS_AGENT_FLEET_STATUS.md`**, **`docs/NEXUS_VISION_ALIGNMENT.md`**, and **`NEXUS_DELIVERY_MATRIX.md`** for gaps their specialty could **assist** (not own).
2. Propose **one** concrete assist action — verification run, doc delta, grep audit, bundle check, pairing with an in-flight primary.
3. End with **`## Brainstorm handoff`** using the template below.
4. **Do not** edit ship-critical code, mark drift FIXED, or spawn subagents.

**PM ingestion:** PM collects brainstorm handoffs into the **Idle / brainstorming** table in fleet status. On Advisor **APPROVED**, PM may move the item to **Recommended retasks** — PM **does NOT auto-spawn** without explicit Advisor **APPROVED** on the brainstorm (same veto list as retasks).

### Brainstorm handoff template (required)

```markdown
## Brainstorm handoff
- Specialty:
- Observed gap:
- Proposed assist:
- Pairs with:
- Priority (P0–P3):
- Advisor check: APPROVED | VETO (reason)
- Evidence needed:
```

### Examples by specialty

| Specialty | Observed gap (example) | Proposed assist | Pairs with |
|-----------|------------------------|-----------------|------------|
| `registry` | V-004 open; validate script may drift after recent mode adds | Grep `ArenaReleaseState` vs `nexus_validate_production_modes.sh` expected set; list mismatches only | `registry` (in flight `4ef42861`) |
| `ios_ship` | V-003 blocked on plist; sim build may still regress | Run `./scripts/build-nexus-ios.sh` + sim xcodebuild; capture PASS/FAIL for when plist lands | `support_build_verify` |
| `debugging` | Multiple agents in flight; gate status unknown | Re-run `./scripts/nexus_build_gate.sh`; attach failing target name if red | in-flight primaries |
| `support_build_verify` | Registry patch landing soon | Pre-stage validate + gate commands; run immediately on registry handoff | `registry` |
| `support_docs_drift` | Fleet **Completed** flood; drift labels may lag | Update **Idle / brainstorming** + honest V-004/V-005 rows from registry evidence | `project_manager` |
| `vision_guardian` | V-006/V-007 fixed; Release grep not re-run this session | Grep `UnrealManager` / `UnityManager` dispatch on Release paths | `ios_ship` |
| `gameplay_tester` | Mode sim coverage unclear for new registry entries | Run `nexus_validate_production_modes.sh --validate-only` for staging modes | `registry` |
| `assets` | Delivery matrix #3 fixed in tree; device proof open | Document bundle manifest checklist for device install verification | `ios_ship`, `assets` |
| `backend` | V-012 OPEN; receipt path may be stubbed | Trace `GameplaySessionReceiptCoordinator` → Firebase POST; list stub vs live | `backend` |
| `renderer` | V-013 needs device; Metal embed may compile on sim | Sim compile + list Instruments steps for user device session | `ios_ship` |
| `docs` | V-011 UE row in gameplay UX bar | Draft corrected NEXUS-only registry row (doc-only) | `docs` |

**Coordinator roles:** `project_manager` idle → **review** brainstorm table, Advisor pass, queue approved items. `senior_advisor` idle → brainstorm **veto-risk** items (UE ship ideas, overclaims) for PM queue.

### Anti-patterns

| Anti-pattern | Why wrong |
|--------------|-----------|
| UE / Unity **production ship** brainstorm | Violates NEXUS-only mandate — Advisor **VETO** |
| Mark drift **FIXED** in brainstorm without build/device/signing evidence | Brainstorm proposes assist only; primary or `vision_guardian` owns FIXED |
| Duplicate **in-flight** work (same drift + same file scope) | Wastes fleet; pair with primary instead |
| Auto-spawn from brainstorm without Advisor **APPROVED** | Breaks control plane; PM queues only |
| Idle agent implements large fix "while brainstorming" | Steals vertical ownership — propose assist, don't own |

---

## Subagent handoff format (required)

Every specialized subagent must end its report with:

```markdown
## Handoff

| Field | Value |
|-------|-------|
| **Status** | complete \| partial \| blocked |
| **Canonical repo** | /Users/elijahbonds/Final-Evolution-Lab |
| **Agent ID** | `<uuid>` (if background subagent) |
| **Specialty** | `<id from nexus_agent_roles.json>` |

### Files changed
- `path/to/file` — one-line why

### Drift IDs
- V-00x: OPEN \| FIXED \| N/A — evidence one line

### Build evidence
- `command` → PASS \| FAIL (one-line result)

### Blockers (if any)
- User action or dependency

### Recommended follow-ups (max 3)
1. [P0|P1|P2|P3] specialty — one line
```

PM ingests this block verbatim into fleet status Completed entry (summary line + link to agent ID if present).

---

## Coordinator reply template

Parent coordinator (human-facing session) should structure replies as:

```markdown
[Summary of what completed and ship impact — 2–4 sentences]

### PM snapshot
1. **P0** — …
2. **P1** — …
3. **P1** — …

### Advisor
- **Approved** | **Vetoed:** [reason + redirect]

### Next retasks
1. …

## Agents working

| Agent | Specialty | Task | Status | Since (UTC) |
|-------|-----------|------|--------|-------------|
| `<uuid or —>` | ios_ship | Real Firebase plist + archive export | queued | — |
| `fd5afa8b-…` | debugging | Fix iOS static lib build | in_flight | 19:34 |
| `a1b2c3d4-…` | support_build_verify | `[support]` Re-run nexus_build_gate after registry patch | in_flight | 20:01 |
| — | — | — | — | — |
```

**Footer rules:**

- Always include **`## Agents working`** as the last section.
- **Status** values: `queued` | `in_flight` | `blocked` | `complete` (recent complete rows optional, max 3).
- PM merges background subagent IDs from Cursor Task tool when available.
- Empty fleet: one row with `—` and status `idle`.

---

## Parent coordinator invocation flow

On **every subagent completion** (Task tool notification or inline agent return):

```
1. READ handoff block from subagent
2. ADVISOR: apply veto list → APPROVED | NEEDS REVISION
3. PM: run checklist → update NEXUS_AGENT_FLEET_STATUS.md
4. PM: select spawn vs resume for 0–3 retasks
5. REPLY to user with template + ## Agents working
```

On **user new request**:

```
1. ADVISOR: classify request vs NEXUS-only mandate
2. PM: insert into priority queue (may bump P2/P3)
3. PM: pick specialty from delegation matrix
4. SPAWN or RESUME subagent with entry prompt template
5. REPLY with ## Agents working (new row in_flight)
```

**Skill shortcut:** activate `nexus-pm-advisor` skill (`~/.cursor/skills/nexus-pm-advisor/SKILL.md`) when user mentions orchestration, fleet, retask, priority, PM, or Senior Advisor.

---

## Spawn vs resume decision tree

```
Subagent finished?
├─ YES → PM checklist + fleet status update
│         └─ Follow-ups needed?
│             ├─ Same specialty + same drift + partial handoff → RESUME (pass agent ID)
│             └─ Else → SPAWN new task with fresh prompt
└─ NO (user interrupt) → PM marks in_flight row blocked or cancelled
```

---

*Maintainers: PM role owns `NEXUS_AGENT_FLEET_STATUS.md`. Vision drift register edits go through `vision_guardian` or explicit user request.*
