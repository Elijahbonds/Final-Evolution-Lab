# Unreal work ↔ Final Evolution Lab vision

Single source of truth for how **UnrealStarter** / **MyProjec** relate to the app: same north star as **`PITCH_DECK.md`**, same schema story as **`app-synopsis.md`** and Swift under **`FinalEvolutionLab/`** — not a standalone arcade product.

---

## North star (from `PITCH_DECK.md`)

- **Measure → train → play** in **one** ecosystem: scan drives **PRQ** and recommendations; curriculum and Academy **train**; **Arena / Lab** **plays** with outcomes tied to readiness.
- **Readiness-gated Arena / Lab** — better PRQ and mode-relevant attributes (**Court IQ**, **Hang Time**, **Shot Accuracy**, etc.) influence odds, feel, and rewards; fair but performance-driven.
- **One avatar / one data story** — scan → avatar → sim; **future Unreal or console** is expected to consume the **same** readiness snapshot and session shapes as iOS, not a forked economy.
- **Philosophy:** *Delete the fear* — coaching and clarity turn intent into output.

**Synopsis layer (`app-synopsis.md`):** **`Sync()`** injects biomechanical data into the sim (impulse, jump, recovery, etc.). Venice-style **Gaming Labs** belong to **FEL Arena**, not generic mini-games.

---

## Honest map of the current Unreal slice

**What this is today:** **Venice / Luma** environment path + **Elijah** stand-in mesh + **basketball modes** (street, shootout, timed blitz, practice, first-to-N) = an **Arena-style lab**: same verbs and naming as the pitch, built to accept real readiness data.

**What is wired in the Unreal lab (C++ under `BasketballGame/` / MyProjec):**

| Track | Status | Notes |
|--------|--------|--------|
| **Data contract** (readiness snapshot) | ✅ Lab | JSON → `FFELReadinessSnapshot` aligned with **`PerformanceMetrics.swift`** (`FELReadinessTypes.h`, `FELReadinessIO`). |
| **PRQ → sim** (character / ball) | ✅ Lab | Jump, move speed, ball mass scale from snapshot (`ApplyReadiness`). |
| **Court IQ / Hang Time** (attribute UX) | ✅ Lab | Labels + display values mirror **`PRQScoring.swift`** (`FELArenaBridge`). **Shot accuracy** as a *gameplay* axis (miss variance, contests) is **not** implemented here yet. |
| **Mode IDs** | ✅ Lab | `GetArenaGameModeId()` ↔ **`GameModeId`** raw strings in **`GameMode.swift`**. |
| **Shards / `GameSessionResult`** | 🟡 Lab file only | Match end writes **`Saved/FEL/last_session_result.json`** (`FELSessionExport`). **Still to wire:** iOS ingest, Firebase, profile **`evolutionShards`**, and production economy rules. |

**Still to wire (product / full vision):**

- **App ↔ Unreal bridge** — push `readiness_snapshot.json` from the device or CI; pull session JSON into **`GameSessionResult`** history.
- **Readiness-gated policy** — soft locks, matchmaking tiers, copy that matches Arena (lives in app first; Unreal can mirror).
- **Deeper attribute modulation** — shot error, fatigue, defender pressure, AI — beyond HUD + light physics tuning. **Neural Drive fatigue** (readiness decay under match load) is **not** implemented in the current C++ templates; add it explicitly (e.g. **Stamina** / **Curve** assets, or time-scaled multipliers on top of `ApplyReadiness`) rather than assuming it exists in repo code.
- **Production avatar** — scan → same rig / preset as hub (Meshy Elijah is a **stand-in**).

**Swift / schema pointers (repo):**

| Topic | File |
|--------|------|
| Snapshot fields | `FinalEvolutionLab/Models/PerformanceMetrics.swift` |
| Session export shape | `FinalEvolutionLab/Models/GameSession.swift` (`GameSessionResult`) |
| Mode ids | `FinalEvolutionLab/Models/GameMode.swift` (`GameModeId`) |
| PRQ weights / labels | `FinalEvolutionLab/Utilities/PRQScoring.swift` |
| Twin pipeline narrative | `app-synopsis.md` |

---

## Guardrails (stay on vision)

1. **Positioning** — Call this **Arena lab / export target**, not “shipped FEL.”
2. **Features** — Prefer work that can take a **readiness snapshot** later (`ApplyReadiness`-style hooks) over one-off rules with no data path.
3. **Naming** — Keep **Arena** language (Venice, beach court, shootout, dunk lineage) consistent with the app.
4. **Modes** — Every new mode gets a row in **`BasketballGame/GAME_MODES.md`** with **how PRQ could affect it** (even if only planned).

---

## Ordered next steps (vision sequence)

Same order as the integration plan; use it when prioritizing tickets.

| Step | Intent | Lab (Unreal) | Product (still to wire) |
|------|--------|----------------|-------------------------|
| 1 | **Data contract** | ✅ JSON snapshot load | Pipe from iOS profile / export |
| 2 | **Tune character / ball from metrics** | ✅ Baseline tuning | Richer **Sync()**-style curves |
| 3 | **Align mode IDs with Swift `GameModeId`** | ✅ | None if ids stable |
| 4 | **Session / economy hooks** | ✅ File export | Ingest shards, **`prqBonus`**, history, sync |

**Follow-ons:** multiplayer fields in export, shot variance, readiness gate UI, tvOS/console packaging.

---

## Repo doc index

| Doc | Role |
|-----|------|
| **`PITCH_DECK.md`** | North star, pillars |
| **`app-synopsis.md`** | Digital twin, **Sync()**, stack |
| **`UnrealStarter/README.md`** | Entry point + link here |
| **`BasketballGame/README.md`** | Arena / Gaming Labs — **not a separate product** |
| **`BasketballGame/GAME_MODES.md`** | Mode rules + PRQ notes + `gameModeId` |
| **`BasketballGame/GAME_FINISHED.md`** | Playable slice vs full PRQ-gated vision |
| **`BasketballGame/PACKAGE_AND_TEST.md`** | Preconditions, maps, input, readiness JSON, Mac **RunUAT** + Editor package, tester checklist, iOS + notarization pointers |
| **`BasketballGame/QA_GAMEPLAY_AUDIT.md`** | Mode matrix, scoring/export QA, Swift parity notes |
| **`IMPORT_CHECKLIST.md`** | Venice / Luma / Elijah asset paths |

---

*Final Evolution Lab — Your movement, audited. Your readiness, your edge.*
