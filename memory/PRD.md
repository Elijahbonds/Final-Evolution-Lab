# Final Evolution Lab - PRD

## Architecture
- Frontend: React 19 + Tailwind + PayPal SDK | Backend: FastAPI + MongoDB + WebSocket
- AI: GPT-5.2/Claude/Gemini via Emergent LLM Key | Auth: Emergent Google OAuth
- Payments: PayPal Sandbox | Streaming: Eagle 3D (E3DS) + Pulumi IaC
- UE Bridge: UFELEmergentBridgeSubsystem → /ws/sovereign WebSocket
- Sovereign Sync: AES-256-GCM → M4 Pro Mac Mini → Private Signaling (Cloudflare Tunnel)

## Live Sovereign Backend (6 Directives)
1. WebSocket Handshake at /ws/sovereign — handles heartbeat, focus_keepalive, match_score, referral, analytics
2. DefaultGame.ini [Emergent] — bFocusKeepalive=True, KeepaliveInterval=0.5, bSovereignSync=True
3. PayPal Monetization Sync — match scores → referral reward chain (FEL-XXXX-XXXXXX)
4. MongoDB → 13 Venues — FEL_VenueRegistry.production.json (Venice Beach → Neuro Arena)
5. AES-256-GCM Encryption — transit (GCM), rest (WiredTiger), tunnel (TLS 1.3)
6. Live Connection Preview — GET /api/sovereign/status (WebSocket + DB + Encryption + INI)

## Full Feature List (20 navigation sections)
Dashboard, System Scan, Game Modes (17), Multiplayer, Creator Cards, Coach Hub,
AI Coach, Education, Brain Brawl, Streaks, Social, Tournaments, Avatar Builder,
Video Critique, Referrals, Analytics, Sovereign Dashboard, Leaderboard, Pixel Stream, Profile
