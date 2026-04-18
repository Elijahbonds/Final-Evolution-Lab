# Final Evolution Lab - PRD

## LOCAL SOVEREIGN MODE
- E3DS: DISABLED | Cloud streaming: False | Video feed: False
- Data feed: Biomechanical (LIVE) | WS: ws://localhost:8888
- PRQ: Local MongoDB (weighted_composite, NOT simulation)
- 13 venues from FEL_VenueRegistry.production.json
- 17 modes (12 production) from FEL_ModeManager.production.json
- AES-256-GCM encryption, no cloud transit

## How It Works
- Visuals: iPhone 16 Pro Max screen (native UE5 app)
- Data: Mac Mini screen (Sovereign Command Center)
- Connection: Tap app → ws://localhost:8888 → Hub turns GREEN
- Numbers move on Mac as you move on court
