# Service URLs & Endpoints Documentation

## Production Endpoints

### Public-Facing Services
| Service | URL | Protocol |
|---------|-----|----------|
| Marketing Website | https://finalevolutiongroup.com | HTTPS |
| Marketing Website (www) | https://www.finalevolutiongroup.com | HTTPS |
| Web Game Client | https://app.finalevolutiongroup.com | HTTPS |
| Streaming Signalling | wss://stream.finalevolutiongroup.com | WSS |
| TURN Server | turn:turn.finalevolutiongroup.com:3478 | TURN/UDP |
| STUN Server | stun:turn.finalevolutiongroup.com:3478 | STUN/UDP |

### Internal Services (localhost on GPU server)
| Service | URL | Purpose |
|---------|-----|---------|
| Signalling Server | http://localhost:8888 | Session management |
| Signalling WebSocket | ws://localhost:8888 | UE5 ↔ Signalling |
| Frontend Dev | http://localhost:3000 | Web app dev server |
| UE5 Pixel Streaming | Internal | Connects to signalling via WS |

---

## API Endpoints

### Signalling Server API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/healthz` | Health check — returns `{"status": "ok"}` |
| GET | `/api/modes` | List all registered game modes |
| GET | `/api/modes/:id` | Get specific game mode details |
| GET | `/api/sessions` | List active streaming sessions |
| POST | `/api/session/create` | Create new streaming session |
| DELETE | `/api/session/:id` | End streaming session |

### WebSocket Messages

| Direction | Message Type | Payload |
|-----------|-------------|----------|
| Server → Client | `playerConnected` | `{"playerId": "..."}` |
| Server → Client | `streamerConnected` | `{"streamerId": "..."}` |
| Client → Server | `launchMode` | `{"mode": "basketball_h2h"}` |
| Client → Server | `exitMode` | `{}` |
| Client → Server | `playExerciseDemo` | `{"exerciseId": "jumping_jacks"}` |
| Server → Client | `modeUpdate` | `{"activeMode": "...", "status": "..."}` |

---

## Game Mode IDs

| # | Mode ID | Display Name |
|---|---------|-------------|
| 1 | `basketball_h2h` | Basketball H2H |
| 2 | `basketball_tournament` | Basketball Tournament |
| 3 | `basketball_practice` | Basketball Practice |
| 4 | `karate_h2h` | Karate H2H |
| 5 | `karate_training` | Karate Training |
| 6 | `soccer` | Soccer |
| 7 | `tennis` | Tennis |
| 8 | `boxing` | Boxing |
| 9 | `swimming` | Swimming |
| 10 | `track_field` | Track & Field |
| 11 | `volleyball` | Volleyball |
| 12 | `gymnastics` | Gymnastics |
| 13 | `wrestling` | Wrestling |
| 14 | `baseball` | Baseball |
| 15 | `obstacle_course` | Obstacle Course |
| 16 | `freestyle_training` | Freestyle Training |

---

## iOS App Configuration

All URLs configured in `ios/FinalEvolutionLab/Config.swift`:

```swift
STREAMING_SERVER_URL  = "wss://stream.finalevolutiongroup.com"
STREAMING_API_URL     = "https://stream.finalevolutiongroup.com"
TURN_SERVER_URL       = "turn:turn.finalevolutiongroup.com:3478"
STUN_SERVER_URL       = "stun:turn.finalevolutiongroup.com:3478"
WEBSITE_URL           = "https://finalevolutiongroup.com"
WEB_APP_URL           = "https://app.finalevolutiongroup.com"
```
