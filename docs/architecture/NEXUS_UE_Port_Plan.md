# NEXUS UE Port Plan — Remaining Work

Phased roadmap after P0/P1 port (arena session, receipts, bridge stubs, venue volumes, HUD queue, exercise demo mappings).

## Phase A — Transport (P2, unblocks backend parity)

1. Add `engine/net/` HTTP client (libcurl or platform URLSession wrapper on iOS).
2. Wire `GameplayManager::dispatchSessionReceipt` to POST `FELBackendConfig` `/api/games/session`.
3. Add WebSocket client for vault (`/ws/vault`) and HUD (`/ws/hud`); drain `FelBridgeService` / `HudRelayService` queues.

## Phase B — Deep link & overlay (P2)

1. Port `UFELDeepLinkSubsystem` INI resolution (`[FELButtonArenaMode]`, `[FELPlayMap]`) to JSON config consumed by NEXUS + iOS.
2. Port `UFELOverlaySubsystem` play-now message parsing; route to `fel.arena.start_session`.

## Phase C — Per-mode gameplay sims (P2)

Port mode-specific logic from UE game modes / Blueprints into focused NEXUS modules:

| Module | UE reference | NEXUS target |
|--------|--------------|--------------|
| Basketball scoring | `AFELGameMode_BasketballH2H`, Dunk, 3v3 | `app/gameplay/modes/basketball_*` |
| Karate HP | `AFELGameMode_KarateH2H`, Endless | `app/gameplay/modes/karate_*` |
| Brain Brawl | `AFELGameMode_BrainBrawl` + `/games/brainstorm/verify` | `app/gameplay/modes/brain_brawl` |

## Phase D — Vault & economy local store (P2)

1. Port `FELVaultDatabase` SQLite schema for offline shard ledger.
2. Expose `fel.query.vault_*` agent queries mirroring `UFELBridgeSubsystem` vault helpers.

## Phase E — Education & montage playback (P2)

1. Resolve UE `UFELExerciseDemoPipelineSubsystem` montage assets in content repo.
2. NEXUS animation playback API (or iOS SceneKit / UE embed) driven by `ExerciseDemoPipeline` paths.

## Phase F — Renderer HUD (P2)

1. In-engine HUD layer consuming `HudRelayService::pendingFrames()`.
2. PRQ/combo/shard widgets matching `BPFL_HUDManager` + `UFELSessionReceiptComponent` delegates.

## Verification matrix

Run after each phase:

```bash
cmake -S . -B build -DNEXUS_BUILD_TESTS=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

Agent smoke:

```json
{"type":"command","id":"1","payload":{"command":"fel.arena.start_session","params":{"mode_id":"basketball_dunk"}}}
{"type":"query","id":"2","payload":{"query":"fel.query.get_session_state"}}
```

## Related docs

- [NEXUS_UE_Port_Inventory.md](./NEXUS_UE_Port_Inventory.md)
- [NEXUS_3D_Milestone.md](./NEXUS_3D_Milestone.md)
