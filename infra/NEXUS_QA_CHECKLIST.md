# Nexus QA Checklist — curl + wscat Commands

Set up:
```bash
export API_BASE=http://localhost:8000
# Start backend: cd backend && MOCK_DB=1 uvicorn server:app --reload --port 8000
```

---

## 1. Health Check
```bash
curl -s $API_BASE/health | jq .
```
**Expected:** `{"status": "healthy", "timestamp": "..."}`

---

## 2. Create Match
```bash
curl -s -X POST $API_BASE/api/matches/create \
  -H 'Content-Type: application/json' \
  -d '{"mode_id":"basketball_h2h"}' | jq .
```
**Expected:**
```json
{ "match_id": "<ID>", "status": "waiting", "mode_id": "basketball_h2h" }
```
Save match ID: `export MATCH_ID=<ID>`

---

## 3. Connect WebSocket (Player 1)
```bash
# In a separate terminal:
wscat -c "ws://localhost:8000/ws/match/$MATCH_ID"
```
**Expected on connect:**
```json
{"type": "match_state", "match": {"match_id": "...", "status": "waiting", ...}}
```

---

## 4. Join Match (Player 2)
```bash
curl -s -X POST $API_BASE/api/matches/join \
  -H 'Content-Type: application/json' \
  -d "{\"match_id\":\"$MATCH_ID\"}" | jq .
```
**Expected:** `{"status": "active", ...}`

**Expected on WS terminal:**
```json
{"type": "match_start", "match_id": "...", "players": [...], "start_time": "..."}
{"type": "score_event", "player_id": "...", "points": 2, "seq": 1, ...}
... (8 total score_events over ~12 seconds)
{"type": "match_end", "score": {...}, ...}
```

---

## 5. Get Match State via HTTP
```bash
curl -s $API_BASE/api/matches/$MATCH_ID | jq '{status:.status, players:.players, score:.score}'
```

---

## 6. Debug Payload (Nexus HTTP polling mode)
```bash
curl -s $API_BASE/api/debug/match/$MATCH_ID/payload | jq .
```
**Expected:** Full match state with `players[]` including `loadout` per player.

---

## 7. Debug System Scan
```bash
curl -s $API_BASE/api/debug/latest-system-scan | jq .
```
**Expected (after calling /api/system-scan/unified):** PRQ metrics, modes unlocked, etc.

---

## 8. Error Cases

### 404 — Match Not Found
```bash
curl -s $API_BASE/api/matches/no-such-id | jq .status_code
# Expected: 404
```

### 409 — Join Active Match
```bash
curl -s -X POST $API_BASE/api/matches/join \
  -H 'Content-Type: application/json' \
  -d "{\"match_id\":\"$MATCH_ID\"}" | jq .
# Expected: 409 "Match already active"
```

---

## 9. Run Backend Tests
```bash
cd backend
MOCK_DB=1 python -m pytest tests/test_matches.py -v
# Expected: 20 passed
```
