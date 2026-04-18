# Final Evolution Lab - PRD

## Architecture
- **Frontend**: React 19 + Tailwind + PayPal SDK
- **Backend**: FastAPI + MongoDB + WebSocket
- **AI**: GPT-5.2/Claude/Gemini via Emergent LLM Key
- **Auth**: Emergent Google OAuth
- **Payments**: PayPal (sandbox)
- **Streaming**: Eagle 3D Streaming (E3DS) — Pulumi IaC + iframe embed + postMessage
- **Design**: Dark clinical vibe (Barlow Condensed + IBM Plex Sans + JetBrains Mono)

## Implemented Features
- Landing page, Google OAuth, Dashboard with PRQ gauge
- System Scan (8 PRQ metrics, health signals, 4 workout plans with live tracker)
- 17 Game Modes (browser-based + E3DS streaming-ready)
- Eagle 3D Streaming: API key configured, iframe embed, 15 game→venue mappings, setup steps UI
- Pulumi IaC: /app/infra/e3ds/ + deploy_e3ds.sh auto-deploy
- Creator Cards marketplace + PayPal
- AI Coach (GPT-5.2/Claude/Gemini)
- Coach Hub (4 coaches, sessions, video critique upload)
- Education (5 courses, certificates, PayPal enrollment)
- Brain Brawl (timer, categories, XP)
- Daily Training Streaks (30-day calendar, milestones)
- Social (discover, follow, challenge, feed)
- Tournaments (4 events, brackets, registration)
- Avatar Builder (full customization)
- Leaderboard, Profile, Coin economy, WebSocket multiplayer

## E3DS Integration Flow
1. API key stored in backend/.env (E3DS_API_KEY)
2. User uploads UE5 build to controlpanel.eagle3dstreaming.com
3. Copies iframe URL → pastes in Pixel Stream connection panel
4. Backend persists URL → iframe loads in stream viewer
5. Game mode buttons send postMessage (ServerTravel) to switch UE5 maps

## Backlog
P1: Multiplayer UI, payment callback, analytics
P2: 3D avatar (Meshy), matchmaking, chat
P3: iOS, AR overlay, forums
