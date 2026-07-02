# NEXUS Snapshot Netcode Contract (Sprint 0)

Status: FOUNDATION — server-authoritative snapshots over the existing match
WebSocket, plus a REST fallback for input ingestion.
Owner: Agent 5 (`nexus/netcode-snapshot`). Server implementation:
`backend/routers/matches.py`.

## Transport

| Channel | Endpoint | Purpose |
|---|---|---|
| WebSocket | `WS /ws/match/{match_id}` | INPUT ingestion + event fan-out + snapshot broadcast |
| REST (fallback) | `POST /api/matches/{match_id}/events` with `type: "input"` | INPUT ingestion when WS is unavailable |

## Message schemas

### 1. Client → Server: INPUT

```json
{
  "type": "input",
  "player_id": "user_123",
  "seq": 42,
  "input": {"action": "charge", "power": 0.83},
  "ts": 1234.567
}
```

- `seq` — client-monotonic input sequence number (per player). The server
  acks the **highest** seq observed; clients must send increasing values.
- `input` — opaque input payload. The server persists it verbatim into
  `match_events` (type `input`) so replays can re-simulate.
- `ts` — client send time (seconds, client clock). Used for RTT estimation
  only; the server never trusts client clocks for simulation.

Server replies immediately on the same socket:

```json
{"type": "input_ack", "player_id": "user_123", "seq": 42}
```

REST fallback body (`POST /api/matches/{id}/events`):

```json
{"type": "input", "player_id": "user_123", "payload": {"seq": 42, "input": {...}, "ts": 1234.567}}
```

### 2. Server → Client: SNAPSHOT (20–30 Hz)

```json
{
  "type": "snapshot",
  "tick": 1287,
  "authoritative_state": {
    "match_id": "abc123",
    "status": "active",
    "score": {"user_123": 7, "user_456": 5},
    "players": ["user_123", "user_456"],
    "event_count": 31
  },
  "last_input_seq_ack": {"user_123": 42, "user_456": 40}
}
```

- Broadcast rate: `FEL_SNAPSHOT_HZ` env var, **clamped to [20, 30] Hz**
  (default 24). The loop runs per active match while at least one WS client
  is connected, and stops on `match_end` or when the room empties.
- `tick` — server-monotonic snapshot counter per match.
- `authoritative_state` — the server's truth. Sprint 0 exposes match-level
  state (status/score/players/event_count). Engine-level entity state
  (positions, physics) will be added when the NEXUS C++ engine
  (`engine/`, bridged via `FinalEvolutionLab/Bridge/NexusGameplayBridge.h`)
  publishes its authoritative world state to the backend.
  TODO(nexus-engine): extend `authoritative_state.entities` once the engine
  export exists — do not invent fields before then.
- `last_input_seq_ack` — per-player highest input seq the server has
  processed. This is the client's reconciliation anchor.

### 3. Existing event messages (unchanged)

`match_state` (on WS connect), `match_start`, `score_event`, `dunk_result`,
`match_end`, `ping`/`pong` keepalive. Snapshots are additive; clients that
ignore `type: "snapshot"` keep working.

## Client reconciliation (prediction + replay)

Algorithm (see `scripts/netcode_client_example.py` for a runnable version):

1. Keep a local `pending` buffer of inputs sent but not yet acked:
   `pending = [(seq, input), ...]`.
2. Apply inputs locally immediately (client-side prediction).
3. On every `snapshot`:
   a. Drop all pending inputs with `seq <= last_input_seq_ack[me]`.
   b. Reset local state to `authoritative_state` (server truth).
   c. Re-apply remaining pending inputs on top (replay).
4. Render the corrected, predicted state.

JavaScript sketch:

```js
let pending = [];
let localState = null;

function sendInput(ws, input) {
  const msg = { type: "input", player_id: ME, seq: ++lastSeq, input, ts: performance.now() / 1000 };
  pending.push(msg);
  applyInput(localState, input);      // predict
  ws.send(JSON.stringify(msg));
}

ws.onmessage = (e) => {
  const msg = JSON.parse(e.data);
  if (msg.type !== "snapshot") return;
  const acked = msg.last_input_seq_ack[ME] ?? 0;
  pending = pending.filter((m) => m.seq > acked);   // 3a
  localState = structuredClone(msg.authoritative_state); // 3b
  for (const m of pending) applyInput(localState, m.input); // 3c
};
```

## Determinism guarantees

- All INPUT messages are persisted to `match_events` with server-assigned
  monotonic `seq`, so `GET /api/matches/{id}/export-replay` contains the full
  input stream and `backend/tools/replay_validator.py` can re-verify results.
- Snapshots are *derived* state and are NOT persisted to the replay log.

## Limits & future work

- Sprint 0 state is match-level only; no entity interpolation/extrapolation.
- No delta compression; snapshots are full-state (fine at 24 Hz for this payload size).
- Input rate limiting and per-connection player auth binding are TODO before
  production (currently `player_id` is client-asserted under MOCK_DB).
