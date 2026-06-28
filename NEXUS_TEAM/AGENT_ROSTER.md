# NEXUS_TEAM — Agent Roster
**Final Evolution Lab (FEL)**  
Branch: `claude/nexus-engine-setup-2qgkik`  
Last Updated: 2026-06-28  
Total Agents: 13 (1 PM + 3 Already Running + 10 Specialists)

---

## PM Agent

| Field | Value |
|---|---|
| **Name** | Nexus Project Manager |
| **Role** | Team lead, documentation, agent orchestration |
| **File Scope** | `NEXUS_TEAM/` directory (all .md files within) |
| **Current Task** | Created project management structure; spawned 10 specialist agents |
| **Status** | DONE |

---

## Already-Running Agents (DO NOT REASSIGN THEIR FILES)

### Agent A — Swift NexusEngine Agent
| Field | Value |
|---|---|
| **Specialty** | iOS Swift / SwiftUI model and ViewModel layer |
| **File Scope** | `FinalEvolutionLab/Models/NexusEngine.swift`, `FinalEvolutionLab/Models/NexusBootSequence.swift`, `FinalEvolutionLab/ViewModels/LabViewModel.swift` |
| **Current Task** | Implementing NexusEngine core model and boot sequence; refactoring LabViewModel to use @Observable pattern |
| **Status** | RUNNING |
| **Do Not Touch** | These 3 files are owned exclusively by this agent |

### Agent B — Backend Modularizer Agent
| Field | Value |
|---|---|
| **Specialty** | Python FastAPI, backend architecture, router extraction |
| **File Scope** | `backend/routers/games.py`, `backend/routers/marketplace.py`, `backend/routers/social.py`, `backend/routers/sovereign.py`, `backend/routers/analytics.py`, `backend/server.py` |
| **Current Task** | Extracting ~2400 LOC FastAPI monolith (server.py) into 5 domain-specific routers with Pydantic models and async Motor |
| **Status** | RUNNING |
| **Do Not Touch** | These 6 files are owned exclusively by this agent |

### Agent C — Frontend Nexus Agent
| Field | Value |
|---|---|
| **Specialty** | React 19, Tailwind CSS, WKWebView dashboard UI |
| **File Scope** | `frontend/src/components/NexusConsole.js`, `frontend/src/components/FELOSDashboard.js`, `frontend/src/App.js` |
| **Current Task** | Building NexusConsole boot animation and FEL OS 4-quadrant dashboard (SCAN/CARDS/ARENA/ACADEMY) |
| **Status** | RUNNING |
| **Do Not Touch** | These 3 files are owned exclusively by this agent |

---

## Specialist Agents (Spawned 2026-06-28)

### Specialist 1 — Game Physics & Mechanics Engineer
| Field | Value |
|---|---|
| **Specialty** | Swift game physics, timing systems, arcade mechanics |
| **File Scope** | `FinalEvolutionLab/Models/GoldenEraEngine.swift`, `FinalEvolutionLab/Models/MatrixPhysicsEngine.swift`, `FinalEvolutionLab/Models/ArcadePhysics.swift`, `FinalEvolutionLab/Models/DefensivePhysics.swift` |
| **Current Task** | (a) Frame-rate independent delta-time in MatrixPhysicsEngine using CACurrentMediaTime(); (b) ComboChain system in GoldenEraEngine (1.1x multiplier per chain, max 5x, 3-second window); (c) PhysicsConstants namespace in ArcadePhysics; (d) HelpDefenseBreakdown struct in DefensivePhysics |
| **Commit Target** | `feat(physics): delta-time, combo chains, physics constants, defense breakdown` |
| **Status** | RUNNING |

### Specialist 2 — Avatar & Biometrics Engineer
| Field | Value |
|---|---|
| **Specialty** | Swift avatar systems, biometric data modeling, performance analytics |
| **File Scope** | `FinalEvolutionLab/Models/AvatarStateMachine.swift`, `FinalEvolutionLab/Models/BiomechanicsAudit.swift`, `FinalEvolutionLab/Models/PerformanceMetrics.swift` |
| **Current Task** | (a) PRQTier enum (Elite/Primed/Ready/Recovering/Depleted) with speed multipliers; (b) MovementEfficiencyScore with 6 sub-scores; (c) PerformanceTrend computed over last 7 sessions + weeklyPeakPRQ/weeklyLowPRQ |
| **Commit Target** | `feat(avatar): PRQ tiers, movement efficiency scoring, performance trends` |
| **Status** | RUNNING |

### Specialist 3 — Economy & Marketplace Engineer
| Field | Value |
|---|---|
| **Specialty** | Swift in-app economy, shard systems, Creator Card marketplace |
| **File Scope** | `FinalEvolutionLab/Models/ShardEconomy.swift`, `FinalEvolutionLab/Models/VaultResources.swift`, `FinalEvolutionLab/Models/CreatorCard.swift` |
| **Current Task** | (a) ShardEarningRule enum + ShardLedger in ShardEconomy; (b) VaultSlot struct + VaultState tracking in VaultResources; (c) CardRarity enum + CardBundle + CreatorCardMetrics in CreatorCard |
| **Commit Target** | `feat(economy): shard ledger, vault slots, card rarity + bundles` |
| **Status** | RUNNING |

### Specialist 4 — Academy & Education Engineer
| Field | Value |
|---|---|
| **Specialty** | Swift education models, curriculum design, tutorial systems |
| **File Scope** | `FinalEvolutionLab/Models/CurriculumTrack.swift`, `FinalEvolutionLab/Models/MovementEducationData.swift`, `FinalEvolutionLab/Models/DrawingInTutorialModels.swift` |
| **Current Task** | (a) LessonDifficulty + QuizQuestion + LessonContent structs in CurriculumTrack; (b) 4 complete BioDigitalModule structs with 5 learning objectives each; (c) TutorialPhase enum + DrawingStroke struct |
| **Commit Target** | `feat(academy): lesson content models, bio-digital modules, tutorial phases` |
| **Status** | RUNNING |

### Specialist 5 — Arena Registry Specialist
| Field | Value |
|---|---|
| **Specialty** | JSON registry management, game mode configuration, cross-file consistency |
| **File Scope** | `backend/FEL_ModeManager.production.json`, `backend/FEL_VenueRegistry.production.json`, `UnrealStarter/BasketballGame/Config/FEL_VenueRegistry.production.json`, `UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json`, `backend/ue_mode_maps.json` |
| **Current Task** | Audit all 19 modes across 5 registry files; ensure completeness of all required fields; add missing entries; validate JSON after each edit |
| **Commit Target** | `feat(registry): complete all 19 mode configs across 5 registry files` |
| **Status** | RUNNING |

### Specialist 6 — Multiplayer & Match Engineer
| Field | Value |
|---|---|
| **Specialty** | Swift matchmaking, 3v3 defense systems, match outcome modeling |
| **File Scope** | `FinalEvolutionLab/Models/Matchmaking.swift`, `FinalEvolutionLab/Models/HelpDefense3v3.swift`, `FinalEvolutionLab/Models/VersusMatchOutcome.swift`, `FinalEvolutionLab/Services/MultipeerService.swift` |
| **Current Task** | (a) MatchmakingConfig per-mode player counts + MatchmakingPool with PRQ bracket; (b) RotationScheme enum + DefensiveSet with coverage zones; (c) XPReward/ShardReward computed properties + MatchReport in VersusMatchOutcome |
| **Commit Target** | `feat(multiplayer): matchmaking config, 3v3 defense schemes, XP/shard rewards` |
| **Status** | RUNNING |

### Specialist 7 — Training & Movement Engineer
| Field | Value |
|---|---|
| **Specialty** | Swift training programs, periodization, movement snack systems |
| **File Scope** | `FinalEvolutionLab/Models/TrainingProgram.swift`, `FinalEvolutionLab/Models/TrainingProgramData.swift`, `FinalEvolutionLab/Models/MovementSnackEngine.swift`, `FinalEvolutionLab/ViewModels/TrainingViewModel.swift` |
| **Current Task** | (a) PeriodizationBlock enum + TrainingPhaseCalendar; (b) 6 complete training programs (4 weeks each); (c) SnackCategory enum + 12 named movement snacks in library; (d) scheduleSnack stub + currentPeriodizationPhase in ViewModel |
| **Commit Target** | `feat(training): periodization blocks, program library, movement snack catalog` |
| **Status** | RUNNING |

### Specialist 8 — QA Test Engineer
| Field | Value |
|---|---|
| **Specialty** | Swift testing (Swift Testing framework), Python pytest, smoke test scripts |
| **File Scope** | `FinalEvolutionLabTests/GameLogicTests.swift`, `backend/tests/test_nexus_systems.py` (new), `scripts/smoke_test_modes.py` |
| **Current Task** | (a) 15+ new @Test cases in GameLogicTests.swift covering all Sprint 1 features; (b) Create 20+ pytest tests in test_nexus_systems.py; (c) Enhance smoke_test_modes.py with JSON schema validation and all-19-modes completeness check |
| **Commit Target** | `test: 15+ Swift tests, 20+ backend tests, enhanced smoke test coverage` |
| **Status** | RUNNING |

### Specialist 9 — CI/DevOps Engineer
| Field | Value |
|---|---|
| **Specialty** | GitHub Actions, shell scripts, deployment pipelines, production readiness |
| **File Scope** | `.github/workflows/nexus-ci.yml` (new), `scripts/verify_production_readiness.sh`, `NEXUS_TEAM/DEPLOYMENT_GUIDE.md` |
| **Current Task** | (a) Create nexus-ci.yml workflow (validate JSON, run pytest, npm build, grep Swift patterns); (b) Enhance verify_production_readiness.sh with STATUS.md check and backend test count gate; (c) Create DEPLOYMENT_GUIDE.md with full local dev + CI setup |
| **Commit Target** | `feat(ci): nexus-ci workflow, enhanced production readiness checks, deployment guide` |
| **Status** | RUNNING |

### Specialist 10 — Leaderboard & Social Engineer
| Field | Value |
|---|---|
| **Specialty** | Swift Firestore queries, social sharing, leaderboard systems, content generation |
| **File Scope** | `FinalEvolutionLab/Services/GlobalLeaderboardService.swift`, `FinalEvolutionLab/Models/LeaderboardEntry.swift`, `FinalEvolutionLab/Services/SocialShareCoordinator.swift`, `FinalEvolutionLab/Services/TrainingLabSocialBridge.swift` |
| **Current Task** | (a) LeaderboardScope enum + fetchLeaderboard async stub + currentUserRank in GlobalLeaderboardService; (b) Sport tag + TrendArrow + BadgeSet in LeaderboardEntry; (c) ShareableContent enum + generateShareCard + shareToSystem in SocialShareCoordinator; (d) PostTemplate enum + generateCaption in TrainingLabSocialBridge |
| **Commit Target** | `feat(social): leaderboard scopes, share cards, post templates, badges` |
| **Status** | RUNNING |
