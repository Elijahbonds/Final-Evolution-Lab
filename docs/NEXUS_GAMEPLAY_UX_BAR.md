# NEXUS Gameplay UX Bar

**Scope:** `app/gameplay/` (app layer) vs generic sports/fitness apps  
**Build gate:** `ctest --test-dir build-headless`  
**Updated:** 2026-06-19

This document compares NEXUS gameplay depth against typical mobile sports apps (2K Mobile, HomeCourt, Nike Training Club, generic arcade sports). It marks what is **shipped in headless logic**, what is **preview/stub**, and what still requires engine/renderer coupling.

---

## Executive summary

| Dimension | Generic sports app | NEXUS today | Target bar |
|-----------|-------------------|-------------|------------|
| Biometric → gameplay coupling | Cosmetic stats or post-session only | FRC/IAP composites drive throw impulse, catch radius, HUD readiness | Real-time, frame-synced |
| Mode orchestration | Single sport loop | 19 registered modes; **9 production simulators** (validate-only); 0 stubs | 12 production modes with distinct feel |
| Creative/LLM terrain | N/A or editor-only | Validated `fel.creative.*` with chunk/bounds feedback | In-session co-editing with visual preview |
| Session receipts / bridge | Cloud leaderboard only | Arena lifecycle + vault WS stub + HTTP POST stub (`/api/games/session`) + disk queue | Cross-platform vault sync + live POST |
| Physics fidelity | Full rigid-body | Intent queue stub; impulses validated in tests | Jolt/rigid-body coupling (engine) |

**Honest verdict:** NEXUS beats generic apps on **protocol depth** (agent commands, fitness schema, mode registry, HUD envelopes) but is still **preview** on renderer feel, ball pickup triggers, and 9/19 outcome-evaluator-only modes.

---

## 1. Throw–catch physics feel

### Shipped (app layer)

- Phase-specific timing: catch 200ms, load 150ms, throw 80ms, recover 300ms
- **Power multiplier** from FRC composite, IAP composite, and power readiness (not raw scalar dump)
- **Catch radius feedback** derived from FRC control → normalized 0.35–0.95 window
- **Breath envelope:** inhale +10% impulse, exhale −6% on throw phase
- **Catch quality boost:** perfect/solid/graze/miss scales impulse 0.92×–1.15×
- **Agent/HUD envelope:** `last_pulse` with `impulse_y`, `breath_boost`, `catch_feedback`, `catch_radius_normalized`
- Horizontal mobility bleed on impulse X (preview coupling to engine body)

### Stub / preview

- No rigid-body catch collision — catch quality is timing-window simulation, not mesh overlap
- Single body ID (`1`) — no multi-player ball entity graph
- Engine logs `Request for Engine API Extension: throw-catch rigid-body coupling`

### vs generic apps

| Generic | NEXUS advantage |
|---------|-----------------|
| Button mash → fixed animation | Biometric-scaled impulse with breath phase |
| No catch feedback taxonomy | miss/graze/solid/perfect + HUD export |
| Session-end PRQ only | Per-tick `fel.hud.poll` throw_catch envelope |

---

## 2. Fitness data (FRC / IAP)

### Shipped

- Thread-safe snapshots with **computed fields:** `frcComposite`, `iapComposite`, `powerReadiness`
- Validation: finite scalars, breath_phase −1/0/1 (strict on partial IAP update), empty partial rejection
- Command responses include `hud` block: composites + `catch_radius_hint`
- Session state + HUD tick frames expose fitness composites for overlay binding

### Stub / preview

- No device SDK ingestion in headless build — commands are agent/simulator fed
- PRQ engine still returns sprint defaults (75, Primed) — not yet wired to live neural drive

### vs generic apps

| Generic | NEXUS advantage |
|---------|-----------------|
| Heart-rate overlay only | FRC/IAP directly modulate gameplay impulse |
| Opaque “readiness score” | Explicit composite breakdown in agent responses |
| Race on partial updates | Mutex snapshot + revision monotonicity |

---

## 3. Creative / voxel (`fel.creative.*`)

### Shipped

- All high-level commands return **creative envelope:**
  - `command`, `region_bounds`, `chunk_count`, `edited_voxels`, `clamped_radius`, `clamped_height`
- raise/lower/flatten/paint/set_voxels/fill_region validated and clamped (radius ≤ 16)
- Paint reports `painted_voxels`; flatten merges multi-pass edit counts

### Stub / preview

- No real-time mesh rebuild in headless CI — chunk count is logical dirty count
- No LLM undo stack or user confirmation UX

### vs generic apps

| Generic | NEXUS advantage |
|---------|-----------------|
| No in-game terrain edit | Agent-addressable voxel ops with bounds feedback |
| External level editor only | Same protocol as gameplay commands (bridge parity) |

---

## 4. Flagship mode integration tests (validate-only)

**9 production simulators** — each has a dedicated `flagship_*_validate_only_integration` case in `tests/unit/gameplay/gameplay_test.cpp`. **0 registry stubs** (see `docs/NEXUS_MODES_CAPABILITY.md`).

| Mode | Registry ID | Test coverage | Sim depth |
|------|-------------|---------------|-----------|
| Basketball dunk | `basketball_dunk` | `flagship_basketball_dunk_validate_only_integration` | Charge→apex→score loop |
| Karate kata | `karate_endless` (kata proxy) | `flagship_karate_kata_validate_only_integration` | Wave spawn, combat envelope, HUD score |
| Venice pickup | `basketball_h2h` @ Venice_Beach_Court | `flagship_venice_pickup_validate_only_integration` | Venue volume travel, throw-catch, bridge |
| Court carnival | `court_carnival` | `flagship_court_carnival_validate_only_integration` | Pad triggers, dice roll, fitness HUD |
| Gymnastics | `gymnastics` | `flagship_gymnastics_validate_only_integration` | Rhythm taps, judge score, routine complete |
| Brain brawl | `brain_brawl` | `flagship_brain_brawl_validate_only_integration` | Trivia answers, correct-count win |
| Skateboarding | `skateboarding` | `flagship_skateboarding_validate_only_integration` | Trick chain, run complete @ win threshold |
| Snowboarding | `snowboarding` | `flagship_snowboarding_validate_only_integration` | Carve/jump, line score @ win threshold, HUD |
| Who Scene It | `who_scene_it` | `flagship_who_scene_it_validate_only_integration` | Buzz-in, answer chain, match complete |

**Note:** `karate_kata` and `venice_pickup` are not separate registry IDs; tests validate production proxies documented above.

---

## 5. Engine / app separation

Maintained boundaries:

| Layer | Path | Responsibility |
|-------|------|----------------|
| Engine | `engine/*` | Physics intent queue, voxel world, agent transport, generative |
| App | `app/gameplay/*` | FEL modes, fitness, HUD relay, session receipts, command parsing |
| Tests | `tests/unit/*` | Link `nexus_gameplay` only — no renderer required |

App code queues `PhysicsIntent` and logs engine extension requests rather than importing renderer/Vulkan/Metal.

---

## 6. Competitor comparison (honest)

### vs 2K / arcade sports mobile

- **Behind:** rendered player fidelity, online matchmaking, licensed rosters
- **Ahead:** biometric-driven impulse, agent command protocol, cross-mode venue registry, creative LLM terrain path

### vs HomeCourt / AI coaching apps

- **Behind:** camera pose estimation, shot form ML
- **Ahead:** unified gameplay loop tying FRC/IAP to physics intent; in-session HUD envelopes; multi-sport mode table

### vs Nike Training Club / fitness games

- **Behind:** content library scale, social feed polish
- **Ahead:** real-time power readiness → throw-catch; session receipts with telemetry envelope; NEXUS venue registry (`nexusMeshPath` + venue tokens per mode — not UE map paths)

---

## 7. Next UX lifts (ordered)

1. Wire throw-catch to engine rigid-body body_id map (remove stub warning)
2. Promote `basketball_h2h` from `kComingSoon` to pickup/score sim
3. Add `karate_kata` as distinct registry alias → form-scored kata (not just endless waves)
4. Live PRQ from session telemetry instead of static 75 default
5. Live vault/HUD WebSocket to backend (stub transport shipped; set `useStubTransport=false` + running `backend` on :8787/:8000)

---

## 8. Bridge / HUD transport

| Surface | Shipped (headless) | Preview / gap |
|---------|-------------------|---------------|
| Vault bridge WS (`/ws/vault`) | `FelBridgeService` + `WebSocketClient` stub — outbound JSON queue + `sentTransportFrames()` | Real WS to backend when `useStubTransport=false` |
| Session HTTP POST | `FelBridgeService::postSessionPayload` + `SessionReceiptClient` → `POST /api/games/session` (stub records body; curl when stub off + `NEXUS_RECEIPT_URL`) | Firebase Bearer on iOS via Swift `SessionReceiptUploadService` |
| HUD relay WS (`/ws/hud`) | `HudRelayService` pending frame queue + stub WS send + `sentTransportFrames()` | Renderer/Swift overlay consuming live `/ws/hud` stream |

**Tests:** `fel_bridge_websocket_stub_sends_outbound`, `hud_relay_websocket_stub_emits_frames`, `session_receipt_http_stub_posts_localhost_contract` in `nexus_gameplay_test`; `nexus_realtime_test` covers `WebSocketClient` + `HttpClient` stub transport.

---

## Verification

```bash
cmake -S . -B build-headless -DNEXUS_ENABLE_RENDERER=OFF -DNEXUS_BUILD_RUNTIME=OFF -DNEXUS_BUILD_TESTS=ON
cmake --build build-headless -j$(sysctl -n hw.ncpu)
ctest --test-dir build-headless --output-on-failure
```

Expected: `nexus_gameplay_test` passes including flagship integration cases.
