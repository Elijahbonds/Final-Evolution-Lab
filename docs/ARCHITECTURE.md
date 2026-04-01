# Final Evolution Lab - System Architecture

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USERS / CLIENTS                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────────────┐ │
│  │  iOS App  │   │ Android  │   │ Web App  │   │ Marketing Site   │ │
│  │  (Swift)  │   │ App      │   │ (React)  │   │ (NextJS)         │ │
│  └─────┬────┘   └────┬─────┘   └────┬─────┘   └────────┬─────────┘ │
│        │              │              │                   │           │
│        └──────────────┼──────────────┘                   │           │
│                       │                                  │           │
│                  WebRTC/WSS                          HTTPS          │
│                       │                                  │           │
└───────────────────────┼──────────────────────────────────┼───────────┘
                        │                                  │
┌───────────────────────┼──────────────────────────────────┼───────────┐
│                 CLOUD INFRASTRUCTURE                      │           │
├───────────────────────┼──────────────────────────────────┼───────────┤
│                       │                                  │           │
│  ┌────────────────────▼────────────────────┐  ┌──────────▼─────────┐ │
│  │     Cloudflare / Load Balancer          │  │  CDN / Static Host │ │
│  │  (DDoS, WAF, SSL Termination)           │  │  (Vercel/Netlify)  │ │
│  └────────────────────┬────────────────────┘  └────────────────────┘ │
│                       │                                              │
│          ┌────────────┼────────────┐                                 │
│          │            │            │                                  │
│  ┌───────▼──────┐ ┌──▼──────────┐ ┌▼─────────────┐                  │
│  │  Signalling  │ │ TURN/STUN   │ │  REST API     │                  │
│  │  Server      │ │ (CoTURN)    │ │  Server       │                  │
│  │  (Node.js)   │ │             │ │               │                  │
│  │  Port 8888   │ │ Port 3478   │ │               │                  │
│  └───────┬──────┘ └─────────────┘ └───────────────┘                  │
│          │                                                           │
│          │ WebSocket                                                 │
│          │                                                           │
│  ┌───────▼───────────────────────────────────────────┐              │
│  │            GPU SERVER (Dedicated)                   │              │
│  │                                                     │              │
│  │  ┌─────────────────────────────────────────────┐   │              │
│  │  │     Unreal Engine 5 Server                   │   │              │
│  │  │                                               │   │              │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────────┐  │   │              │
│  │  │  │ 16 Game  │ │ 23 3D    │ │ AI Asset     │  │   │              │
│  │  │  │ Modes    │ │ Exercises│ │ Manager      │  │   │              │
│  │  │  └──────────┘ └──────────┘ └──────────────┘  │   │              │
│  │  │                                               │   │              │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────────┐  │   │              │
│  │  │  │ Pixel    │ │ Physics  │ │ Animation    │  │   │              │
│  │  │  │ Streaming│ │ Engine   │ │ Blueprint    │  │   │              │
│  │  │  └──────────┘ └──────────┘ └──────────────┘  │   │              │
│  │  └─────────────────────────────────────────────┘   │              │
│  └─────────────────────────────────────────────────────┘              │
│                                                                       │
│  ┌─────────────────────────────────────────────────────┐              │
│  │           AI ASSET PIPELINE                          │              │
│  │                                                       │              │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────────┐   │              │
│  │  │ DeepMotion │ │ Meshy      │ │ Luma AI        │   │              │
│  │  │ MoCap      │ │ 3D Gen     │ │ Image/Video    │   │              │
│  │  └────────────┘ └────────────┘ └────────────────┘   │              │
│  └─────────────────────────────────────────────────────┘              │
└───────────────────────────────────────────────────────────────────────┘
```

## Component Details

### Client Layer
| Component | Technology | Purpose |
|-----------|-----------|----------|
| iOS App | Swift, WebRTC | Native Pixel Streaming client with HealthKit |
| Android App | Kotlin, WebRTC | Native Pixel Streaming client |
| Web App | React, Vite, TypeScript | Browser-based game client |
| Marketing Site | Next.js 16, Tailwind CSS | Finalevolutiongroup.com |

### Streaming Infrastructure
| Component | Technology | Port | Purpose |
|-----------|-----------|------|----------|
| Signalling Server | Node.js, Express, WebSocket | 8888 | Session management, WebRTC signalling |
| TURN/STUN Server | CoTURN | 3478, 49152-65535 | NAT traversal, media relay |
| Frontend Server | Vite/Serve | 3000 | Web app hosting (dev) |

### Game Engine
| Component | Technology | Purpose |
|-----------|-----------|----------|
| UE5 Server | Unreal Engine 5.4 | Game rendering, physics, Pixel Streaming |
| 16 Game Modes | UE5 Blueprints + C++ | Basketball, Karate, Soccer, etc. |
| 23 Exercises | DeepMotion animations | Motion-captured fitness exercises |
| AI Asset Manager | C++ Subsystem | Runtime loading of AI-generated assets |

### AI Pipeline
| Service | Purpose | Assets Generated |
|---------|---------|------------------|
| DeepMotion | Motion capture from video | 23 exercise animations, 54 athlete moves |
| Meshy | Text/Image to 3D | 9 props, 8 environments |
| Luma AI | Reference images/videos | 12 venue references |

---

## Data Flow: Game Session

```
1. User opens app → connects to wss://stream.finalevolutiongroup.com
2. Signalling server assigns player ID → routes to available UE5 instance
3. UE5 server starts game mode → begins Pixel Streaming encode
4. Video frames: UE5 → H.264/VP8 encode → WebRTC → TURN relay → Client
5. Input: Client touch → WebRTC data channel → UE5 input handler
6. Latency budget: <30ms end-to-end
```

## Service URLs

| Service | URL |
|---------|-----|
| Marketing Website | https://finalevolutiongroup.com |
| Web App | https://app.finalevolutiongroup.com |
| Streaming Signalling | wss://stream.finalevolutiongroup.com |
| REST API | https://stream.finalevolutiongroup.com/api/* |
| TURN Server | turn:turn.finalevolutiongroup.com:3478 |
| STUN Server | stun:turn.finalevolutiongroup.com:3478 |
