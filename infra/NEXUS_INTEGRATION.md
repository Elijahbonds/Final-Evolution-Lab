# Nexus Integration — WS/HTTP Contracts

## Overview

The FEL OS backend exposes both a REST API and a WebSocket channel for match lifecycle management. The Nexus engine (Swift/UE5) connects to these endpoints to drive in-game scoreboards, loadout data, and event feeds.

---

## HTTP Endpoints

### POST /api/matches/create
Create a new match in "waiting" state.

**Request:**
```json
{ "mode_id": "basketball_h2h" }
```
**Response:**
```json
{ "match_id": "a1b2c3d4e5f6", "status": "waiting", "mode_id": "basketball_h2h" }
```

---

### POST /api/matches/join
Join an existing match. When a second player joins, status transitions to "active" and `match_start` is broadcast over WebSocket.

**Request:**
```json
{ "match_id": "a1b2c3d4e5f6" }
```
**Response:**
```json
{ "match_id": "a1b2c3d4e5f6", "status": "active", "players": ["player_a", "player_b"] }
```

---

### GET /api/matches/{match_id}
Returns current match state and last 20 events.

**Response fields:** `match_id`, `mode_id`, `status`, `players`, `score`, `loadouts`, `events`

---

### GET /api/debug/match/{match_id}/payload
Full match payload for Nexus to poll (same data as WS, useful if WS not yet wired).

---

### GET /api/debug/latest-system-scan
Last cached `/api/system-scan/unified` snapshot. Use to seed PRQ/stats before match start.

---

## WebSocket Channel

**Endpoint:** `ws://<host>/ws/match/{match_id}`

### On Connect
Server immediately sends current match state:
```json
{
  "type": "match_state",
  "match": { "match_id": "...", "status": "waiting", "players": [], "score": {} }
}
```

### match_start
Broadcast when match transitions to "active":
```json
{
  "type": "match_start",
  "match_id": "a1b2c3d4e5f6",
  "mode_id": "basketball_h2h",
  "players": [
    { "user_id": "player_a", "loadout": [{ "id": "card_x", "title": "Speed Boost", "modifiers_summary": "+15% agility" }] },
    { "user_id": "player_b", "loadout": [] }
  ],
  "start_time": "2026-07-01T10:00:00+00:00"
}
```

### score_event
Emitted for each scoring play (simulated every ~1.5s during stub mode):
```json
{
  "type": "score_event",
  "player_id": "player_a",
  "points": 2,
  "seq": 3,
  "timestamp": "2026-07-01T10:00:07.123456+00:00",
  "score_snapshot": { "player_a": 6, "player_b": 4 }
}
```
- Use `seq` for ordering/deduplication. Ignore events with lower seq than highest seen.

### match_end
```json
{
  "type": "match_end",
  "match_id": "a1b2c3d4e5f6",
  "score": { "player_a": 14, "player_b": 10 },
  "timestamp": "2026-07-01T10:00:22+00:00"
}
```

### ping/pong
Server sends `{"type": "ping"}` every 30s. Client should respond with `"ping"` text to keep connection alive.

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `MONGODB_URI` | Yes (prod) | MongoDB connection string |
| `DB_NAME` | Yes (prod) | MongoDB database name |
| `JWT_SECRET` | Yes (prod) | Auth session signing key |
| `EMERGENT_LLM_KEY` | Yes (prod) | LLM API key for AI features |
| `MOCK_DB` | Dev only | Set to `"1"` to use in-memory store, no MongoDB needed |

---

## Local Dev Quick Start

```bash
# Start backend with in-memory store (no MongoDB)
cd backend
MOCK_DB=1 uvicorn server:app --reload --port 8000

# Open playtest page
open frontend/public/playtest.html
```
