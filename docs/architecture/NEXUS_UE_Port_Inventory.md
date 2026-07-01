# NEXUS UE 5.7 Port Inventory

Inventory of Final Evolution Lab Unreal Engine 5.7 integration code mapped to NEXUS C++ modules (`app/gameplay/`, `engine/`).

**Source of truth (UE):** `UnrealIntegration/Source/FinalEvolutionLab/`  
**NEXUS target:** `app/gameplay/include/nexus/gameplay/`

## Summary

| Category | UE classes inventoried | P0/P1 ported | Stubbed | Deferred (P2) |
|----------|------------------------|--------------|---------|---------------|
| Gameplay / session | 6 | 4 | 1 | 1 |
| Bridge / backend | 3 | 2 | 1 | 0 |
| Spatial / venue | 1 | 1 | 0 | 0 |
| HUD | 2 | 1 | 1 | 0 |
| Education / overlay | 6 | 0 | 0 | 6 |
| **Total** | **18** | **8** | **3** | **7** |

---

## P0 / P1 — Ported or stubbed in NEXUS

| UE class | Responsibility | NEXUS equivalent | Status | Priority |
|----------|----------------|------------------|--------|----------|
| `FELTypes.h` (`EFELMatchOutcome`, `FFELSessionResult`) | Canonical session outcome + economy candidates | `fel_session_types.h` | **Exists** | P0 |
| `UFELGameplayManager` | 19-mode outcome evaluators, XP/shard/PRQ economy, session receipt POST | `gameplay_manager.h/.cpp` | **Exists** (HTTP dispatch stubbed) | P0 |
| `AFELGameModeBase` + 19 subclasses | Per-mode match lifecycle, scoring flags, duration | `arena_mode_registry.h/.cpp`, `arena_session_manager.h/.cpp` | **Exists** | P0 |
| `UFELBridgeSubsystem` | Vault WS routing, venue travel, map loaded, telemetry, dual envelope | `fel_bridge_service.h/.cpp` | **Stubbed** (outbound queue + logs; no WS) | P0 |
| `AFELVenueVolume` | Box overlap → `NotifyVenueTravel` | `venue_volume_registry.h/.cpp` | **Exists** | P1 |
| `UFELHudRelaySubsystem` | `/ws/hud` overlay frames | `hud_relay_service.h/.cpp` | **Stubbed** (pending frame queue) | P1 |
| `UFELExerciseDemoPipelineSubsystem` (referenced in AGENTS.md) | Mode → Academy mod1–mod12 montages | `exercise_demo_pipeline.h/.cpp` | **Exists** (data mapping) | P1 |
| `UFELSessionReceiptComponent` | Reward HUD delegates after match | Wired via `fel.arena.end_session` + `hud_relay_service` | **Partial** | P1 |
| `GameplayApplication` integration | Agent fel.* command surface | Extended commands/queries in `gameplay_application.cpp` | **Exists** | P0 |

### NEXUS agent commands (new)

| Command / query | UE origin |
|-----------------|-----------|
| `fel.arena.start_session`, `fel.arena.end_session`, `fel.arena.set_mode`, `fel.arena.update_score` | `AFELGameModeBase::StartMatch` / `EndMatch` |
| `fel.bridge.notify_venue_travel`, `fel.bridge.broadcast_map_loaded`, `fel.bridge.set_focus_keepalive` | `UFELBridgeSubsystem` |
| `fel.venue.register_volume`, `fel.venue.set_player_position` | `AFELVenueVolume` |
| `fel.hud.broadcast` | `UFELHudRelaySubsystem::BroadcastMessage` |
| `fel.query.get_arena_state`, `fel.query.list_arena_modes`, `fel.query.get_exercise_demo`, `fel.query.get_bridge_outbound`, `fel.query.get_pending_session_receipts` | Various UE subsystems |

---

## P2 — Deferred (engine API or UE-only)

| UE class | Responsibility | NEXUS plan | Priority |
|----------|----------------|------------|----------|
| `UFELDeepLinkSubsystem` | INI button → arena mode → map travel | iOS `DeepLinkService` + future NEXUS transport | P2 |
| `UFELOverlaySubsystem` | Web overlay JSON → play requests | iOS WebView bridge; NEXUS needs overlay compositor | P2 |
| `UFELPerformanceManagerSubsystem` | Device tier / quality presets | `engine/renderer` quality tiers | P2 |
| `UFELNeuroCognitiveSubsystem` | Cognitive telemetry hooks | Extend fitness + backend API | P2 |
| `UFELVaultDatabase` + SQLite ledger | Local shard/draft persistence | New `engine/assets` or platform storage module | P2 |
| `UFELWebBridgeComponent` | Per-actor web bridge | Not applicable to headless NEXUS runtime | P2 |
| `FELEducationEngine`, `UFELMovementLabMode`, `FELAnatomyExplorer`, `FELResonanceHUD` | Academy / movement lab education | Swift UI + future animation pipeline | P2 |
| `BPFL_HUDManager` | Blueprint HUD widget routing | NEXUS renderer HUD layer | P2 |
| Per-mode UE `.cpp` game rules (basketball shot, karate HP, etc.) | Full sport simulations | Mode-specific gameplay modules in NEXUS | P2 |

---

## Arena modes (19)

Aligned with `FinalEvolutionLab/Models/GameMode.swift` and `FELGameplayManager` mode weights.

| mode_id | Release | NEXUS registry | Outcome evaluator |
|---------|---------|------------------|-------------------|
| basketball_h2h | production | ✅ | ✅ |
| basketball_dunk | production | ✅ | ✅ |
| basketball_3v3 | production | ✅ | ✅ |
| karate_h2h | production | ✅ | ✅ |
| karate_endless | production | ✅ | ✅ |
| baseball | production | ✅ | ✅ |
| football | production | ✅ | ✅ |
| soccer | production | ✅ | ✅ |
| golf | production | ✅ | ✅ |
| tennis | production | ✅ | ✅ |
| volleyball | production | ✅ | ✅ |
| gymnastics | staging | ✅ | ✅ |
| surfing | production | ✅ | ✅ |
| skateboarding | staging | ✅ | ✅ |
| snowboarding | staging | ✅ | ✅ |
| brain_brawl | staging | ✅ | ✅ |
| who_scene_it | preview | ✅ | ✅ |
| court_carnival | preview | ✅ | ✅ |
| market_browse | non-game | ✅ | ✅ (always draw) |

**Note:** `EFELArenaMode` is referenced in product docs as the 12-mode shipping enum; the UE C++ layer uses string `mode_id` keys across 19 modes in `FELGameplayManager` and `FELGameModeBase`.

---

## Engine API extensions logged

1. **HTTP client** — POST `/api/games/session` session receipts (`FELBackendConfig::ResolveSessionReceiptUrl`)
2. **WebSocket client** — Vault bridge `/ws/vault` and HUD relay `/ws/hud`
3. **Renderer HUD** — consume `HudRelayService` pending frames
4. **Physics triggers** — native overlap volumes (currently AABB registry + manual player position)
