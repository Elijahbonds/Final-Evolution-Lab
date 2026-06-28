# NEXUS_TEAM — Master Project Plan
**Final Evolution Lab (FEL)**  
Branch: `claude/nexus-engine-setup-2qgkik`  
Last Updated: 2026-06-28  
PM: Nexus Project Manager Agent

---

## Vision Statement

Final Evolution Lab is the world's first athlete-first superapp: a unified iOS platform where real biomechanical performance (via HealthKit PRQ scanning) powers a digital avatar, unlocks 19 Unreal Engine 5.7 game modes, fuels a Creator Card marketplace, and drives a complete education pathway from Common Core through an Applied Kinesiology Certificate. The FEL OS pillars — SCAN, CARDS, ARENA, ACADEMY — converge into a single dashboard that makes every workout, every match, every lesson matter.

---

## Current Sprint Goal (Sprint 1 — Nexus Engine Setup)

**Goal:** Wire the NexusEngine model layer into the iOS Swift shell, modularize the FastAPI backend, and deliver the React FEL OS Dashboard — establishing the full-stack foundation that all 19 game modes and 4 education tracks can run on.

**Sprint 1 Dates:** 2026-06-28 → 2026-07-11  
**Success Metric:** NexusEngine boot sequence compiles, backend routers split from server.py monolith, FEL OS 4-quadrant dashboard renders in browser.

---

## Milestone Roadmap

### Sprint 1 — Nexus Engine Foundation (2026-06-28 → 2026-07-11)
| Deliverable | Owner Agent | Status |
|---|---|---|
| NexusEngine.swift + NexusBootSequence.swift | Swift NexusEngine Agent | RUNNING |
| LabViewModel.swift refactor | Swift NexusEngine Agent | RUNNING |
| backend/routers/ split (games, marketplace, social, sovereign, analytics) | Backend Modularizer Agent | RUNNING |
| NexusConsole.js + FELOSDashboard.js + App.js | Frontend Nexus Agent | RUNNING |
| Physics engine enhancements (4 files) | Specialist 1 — Physics | RUNNING |
| Avatar PRQ tiers + biomechanics scoring | Specialist 2 — Avatar | RUNNING |
| Shard ledger + vault slots + card rarity | Specialist 3 — Economy | RUNNING |
| Academy lesson models + Bio-Digital modules | Specialist 4 — Academy | RUNNING |
| All 19 mode registry audit + completion | Specialist 5 — Arena Registry | RUNNING |
| Matchmaking config + 3v3 defense + XP rewards | Specialist 6 — Multiplayer | RUNNING |
| Periodization + training programs + movement snacks | Specialist 7 — Training | RUNNING |
| 35+ new tests (Swift + Python) | Specialist 8 — QA | RUNNING |
| nexus-ci.yml + production readiness script | Specialist 9 — DevOps | RUNNING |
| Leaderboard scopes + share cards + post templates | Specialist 10 — Social | RUNNING |
| NEXUS_TEAM/ project management docs | PM Agent (you) | DONE |

### Sprint 2 — Economy Integration & Arena Polish (2026-07-12 → 2026-07-25)
| Deliverable | Target Agent |
|---|---|
| PRQ delta → HUD display in UE5 session receipt | Economy + Arena |
| Shard ledger read API `/api/economy/balance` | Backend |
| Creator Card drop system (gameplay → inventory) | Economy + Backend |
| IAP integration (StoreKit, shard packs, sovereign pass) | Native iOS |
| Brain Brawl standardization → standard session receipt | Arena Registry |
| Staging mode promotion gates (skateboarding, snowboarding, gymnastics) | Arena Registry |
| who_scene_it gameplay prototype | Arena + Frontend |
| Full test suite green (all 35+ tests pass) | QA |

### Sprint 3 — Production Readiness & App Store Prep (2026-07-26 → 2026-08-08)
| Deliverable | Target Agent |
|---|---|
| iOS shipping package: `./fel_ue5_ios_shipping_package.sh --shipping` | DevOps / PM |
| Applied Kinesiology Certificate compound index on education_progress | Backend |
| Brain Brawl live web preview (browser fallback) | Frontend |
| Localization (en-US + es + pt-BR + ja + ko) | Frontend |
| Full system validation: 147+ smoke tests, 33+ economy tests | QA + DevOps |
| App Store submission: screenshots, metadata, TestFlight | PM |
| Final PRQ weight confirmation for staging modes | Arena + Economy |

---

## Feature Backlog

### P0 — Required for Internal Testing Track
| Feature | Status | Owner |
|---|---|---|
| NexusEngine boot sequence (Swift) | IN PROGRESS | Swift Nexus Agent |
| FastAPI router modularization | IN PROGRESS | Backend Modularizer |
| FEL OS 4-quadrant dashboard | IN PROGRESS | Frontend Nexus Agent |
| All 19 modes registered in all 6 registries | IN PROGRESS | Specialist 5 |
| Physics: delta-time + combo chains | IN PROGRESS | Specialist 1 |
| PRQ tiers on AvatarStateMachine | IN PROGRESS | Specialist 2 |
| ShardLedger transaction history | IN PROGRESS | Specialist 3 |
| iOS shipping package script | BACKLOG | Sprint 3 |
| 12 production modes compiling/running (UE5 on macOS) | BLOCKED — needs macOS | Sprint 3 |

### P1 — Required for Open Beta Track
| Feature | Status | Owner |
|---|---|---|
| Full server.py → routers refactor (all remaining endpoints) | IN PROGRESS (partial) | Backend Modularizer |
| `(education_progress.user_id, track_id)` compound index | BACKLOG | Sprint 2 |
| Brain Brawl cooldown/TTL on `brain_brawl_launches` | BACKLOG | Sprint 2 |
| Matchmaking PRQ bracket matching (±15 PRQ) | IN PROGRESS | Specialist 6 |
| Training periodization blocks | IN PROGRESS | Specialist 7 |
| nexus-ci.yml GitHub Actions workflow | IN PROGRESS | Specialist 9 |
| 35+ automated tests covering Sprint 1 features | IN PROGRESS | Specialist 8 |

### P2 — Required for Production Track
| Feature | Status | Owner |
|---|---|---|
| Auth gating on lesson detail endpoint | BACKLOG | Sprint 3 |
| Brain Brawl browser fallback mini-game | BACKLOG | Sprint 3 |
| Track-specific certificates (Common Core, STEM) | BACKLOG | Sprint 3 |
| Localization (5 languages) | BACKLOG | Sprint 3 |
| Social share cards (UIImage generation) | IN PROGRESS | Specialist 10 |
| Post templates (5 templates, emoji captions) | IN PROGRESS | Specialist 10 |

---

## Definition of Done (Per Feature Area)

### Swift Models/Services
- File compiles without errors (verified via `swiftc -typecheck` on macOS)
- Uses `@Observable` for state models, `@MainActor` for UI-bound classes
- All async operations use `async/await` (no completion handlers)
- Logging via `OSLog` (zero `print()` statements)
- Zero force-unwraps (`!`) — use `guard let` or `if let`
- New types have associated unit tests in `FinalEvolutionLabTests/`

### Python Backend
- Router follows patterns in `backend/core.py` (Motor async, Pydantic models, `get_current_user` dep)
- All endpoints typed with Pydantic request/response models
- All DB operations use `async Motor` (no sync PyMongo)
- New endpoints covered by pytest tests in `backend/tests/`
- `python3 -m pytest backend/tests/ -v` passes with 0 failures

### React Frontend
- Functional components only (no class components)
- Styling via Tailwind CSS only (no inline styles, no CSS modules)
- All interactive elements have `data-testid` attributes
- No hardcoded colors — use Tailwind palette or CSS variables
- `npm run build` succeeds with 0 errors

### Registry Files (6 registries)
- All 6 registries agree on every mode's ID, venue, and map path
- `python3 -m json.tool <file>` passes (valid JSON)
- `python3 scripts/smoke_test_modes.py` passes 0 failures
- All 19 modes present with all required fields

### Git Commits
- Conventional commit format: `feat(scope): description`
- Stage only own file scope (never `git add -A` or `git add .`)
- `git pull --rebase origin claude/nexus-engine-setup-2qgkik` before push
- Push with exponential backoff retry on conflict

---

## Tech Stack Summary & Constraints

| Layer | Technology | Notes |
|---|---|---|
| Game Engine | Unreal Engine 5.7 | Native iOS host — NOT buildable in this Linux env |
| iOS Shell | Swift 5.9 / SwiftUI | Can write/edit files; cannot compile on Linux |
| Backend | FastAPI (Python 3.11) + Motor + MongoDB + Firestore | Fully runnable on Linux |
| Frontend | React 19 + Tailwind CSS | WKWebView overlay + web parity |
| Database | MongoDB (Motor async) + Firestore | Motor for game data, Firestore for realtime |
| IAP | StoreKit (iOS) | Requires macOS + Apple dev account |
| Analytics | Firebase Crashlytics + Remote Config | Config only in this env |
| Deep Links | `finalevolution://` URL scheme | Parsed by UE5 subsystem |
| CI | GitHub Actions (ubuntu-latest) | No UE5 cook in CI — validation only |

**Hard Constraints:**
1. UE5 compilation and iOS archive builds require macOS with Xcode + UE 5.7 installed
2. Swift type-checking requires macOS (`swiftc` not available in this Linux env)
3. All 6 registries must be updated atomically when any mode changes
4. `market_browse` is NOT a game mode — no session receipt, PRQ, or shards
5. Preview modes (`who_scene_it`, `court_carnival`) must not be promoted without session receipts
6. `XP_CAP_PER_SESSION = 500` — never increase without economy review
