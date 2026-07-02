# 01 — Gameplay Loop Protocol

**Spec:** Phase 0 Foundation  
**Implementation:** `GameplayApplication`, `ThrowCatchPhysicsController`, `core::Engine`

Defines the app-layer update hook and the reference throw-catch gameplay module that consumes fitness data and emits physics intents.

## GameplayApplication responsibilities

`GameplayApplication` implements:

- `core::ApplicationUpdateHook::update` — post-physics gameplay tick.
- `ai::GameplayCommandHandler` — `fel.fitness.*`, `fel.creative.*`, `fel.query.*`.

### Update stats (`GameplayUpdateStats`)

| Field | Meaning |
|-------|---------|
| `processedAgentMessages` | Agent responses drained this frame |
| `latestAgentErrors` | Count of responses with `status == "error"` |
| `updatesCompleted` | Total `update` calls |

## Throw-catch phase machine

`ThrowCatchPhysicsController` cycles every **0.25 s** per phase:

```
Catch → Load → Throw → Recover → Catch …
```

| Phase | Behavior |
|-------|----------|
| **Catch** | Advance to Load |
| **Load** | Advance to Throw |
| **Throw** | Increment `throwsTriggered`; queue `kApplyImpulse` on body `1` with Y impulse `8.0 × powerMultiplier` |
| **Recover** | Advance to Catch |

### Power multiplier

Derived each frame from latest fitness snapshot:

```
frcScore = mean(mobility, activeRange, control)   // clamped 0–1
iapScore = engagement × confidence                // clamped 0–1
powerMultiplier = 1.0 + frcScore×0.35 + iapScore×0.25
```

High FRC + IAP scores increase throw impulse, linking biometric input to arcade physics feedback.

## Integration with agent drain

End-to-end flow (validated in `gameplay_update_drains_agent_commands_before_throw_catch`):

1. Agent JSON `fel.fitness.update` received by `AgentServer`.
2. Engine tick drains queue → `CommandRouter` → fitness revision increments.
3. Same tick: gameplay `update` runs throw-catch with new fitness view.
4. After sufficient phase time at full fitness, throw impulse exceeds baseline (test expects Y > 12).

## Queries

See [IntegrationManual.md](./IntegrationManual.md) for `fel.query.get_session_state` payload shape.

## Files

| File | Role |
|------|------|
| `gameplay_application.h/.cpp` | Command routing, session state |
| `throw_catch_physics.h/.cpp` | Phase machine + physics intents |
| `fitness_data.h/.cpp` | Thread-safe metric store |
| `voxel_command_parser.h/.cpp` | Creative command adapter |
