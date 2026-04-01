# FEL Pixel Streaming Infrastructure

This directory contains the deployment and configuration files for running
Final Evolution Lab's 16 game modes via Unreal Engine Pixel Streaming.

## Architecture

```
┌───────────────────┐    WebRTC     ┌───────────────────┐    HTTP/WS    ┌───────────────────┐
│  UE5 Game Server │──────────▶│ Signalling Server │──────────▶│   Web Frontend    │
│  (Pixel Streaming │           │  (Node.js/WS)    │           │   (React/TS)      │
│   + Data Channel) │           │                   │           │                   │
└───────────────────┘           └───────────────────┘           └───────────────────┘
        │                                                           │
        │              Data Channel (JSON)                          │
        └───────────────────────────────────────────────────┘
```

## Components

1. **UE5 Game Server** (`docker/Dockerfile.ue-server`) — Headless UE5.7 with Pixel Streaming enabled
2. **Signalling Server** (`signalling/`) — WebSocket relay between UE and browsers
3. **TURN/STUN** (`docker/coturn/`) — NAT traversal for WebRTC
4. **Web Frontend** (`frontend/`) — React app with mode selector + streaming player
5. **Docker Compose** (`docker-compose.yml`) — One-command deployment

## Quick Start

```bash
cd streaming
docker-compose up --build
```

Frontend: http://localhost:3000
Signalling: ws://localhost:8888
TURN: localhost:3478

## Data Channel Protocol

The app communicates with UE5 via JSON messages on the Pixel Streaming data channel:

### App → UE5
```json
{"command": "launch_mode", "payload": {"mode_key": "basketball_h2h"}}
{"command": "exit_mode"}
{"command": "get_modes"}
{"command": "exercise_demo", "payload": {"exercise_id": "squat_form"}}
{"command": "get_status"}
```

### UE5 → App
```json
{"response": "launch_mode_result", "success": true, "mode_key": "basketball_h2h"}
{"response": "modes_manifest", "manifest": "..."}
{"response": "status", "connected": true, "mode_active": true, "current_mode": "soccer"}
```

## 16 Game Modes Available

| # | Mode Key | Display Name | Venue |
|---|----------|-------------|-------|
| 1 | basketball_h2h | Street · 1v1 | Venice Beach |
| 2 | basketball_dunk | Dunk Contest | Venice Beach |
| 3 | basketball_3v3 | Street · 3v3 | Venice Beach |
| 4 | karate_h2h | Karate · 1v1 | Dojo |
| 5 | karate_endless | Karate · Endless | Dojo |
| 6 | baseball | Baseball · Ballpark | Baseball Park |
| 7 | football | Football · Kick Return | Gridiron |
| 8 | soccer | Soccer · Stadium | Soccer Stadium |
| 9 | golf | Golf · Links | Links |
| 10 | tennis | Tennis · Court | Tennis Court |
| 11 | volleyball | Volleyball · Sand | Sand Court |
| 12 | gymnastics | Gymnastics · Floor | Training Floor |
| 13 | brain_brawl | Academy · Brain Brawl | Neuro Arena |
| 14 | surfing | Surf · Line | Venice Beach |
| 15 | skateboarding | Skate · Park | Dojo |
| 16 | snowboarding | Snow · Line | Training Floor |
| — | market_browse | Sovereign Shop | Luma Venice Shop |
