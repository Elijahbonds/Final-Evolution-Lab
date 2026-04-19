# Final Evolution Lab - PRD

## SOVEREIGN COMMAND CENTER — PRODUCTION

### Status
- WebSocket: LISTENING on ws://localhost:8888
- Database: READY (13 venues, Local MongoDB)
- Integrity Guard: AWAITING_AUTH (bIsHardwareAuthenticated + back camera)
- PRQ: Local MongoDB (weighted_composite, NOT simulation)
- Cloud: DISABLED | E3DS: BYPASSED | Video: NONE
- Data feed: Biomechanical (telemetry frames)

### Telemetry Protocol (AFELBasketballGameState)
- PRQ Score, Combo Meter, Buckets, Vertical Jump, Velocity Vectors
- 30-day vertical jump tracking in vertical_jump_log collection
- Creator Card lookup via StoodCardId → instant profile display

### Integrity Guard
- bIsHardwareAuthenticated flag from iPhone back camera
- IMU-Visual Sync validation
- Dashboard shows ACTIVE only if all checks pass
- WARNING state triggers alert on Vizio display

### Architecture
Phone (UE5 visuals) → ws://localhost:8888 → Sovereign Hub → Local MongoDB
Mac Mini (Command Center) → reads MongoDB → displays telemetry + PRQ + Integrity
Vizio (Stadium View) → 75 PRQ overlay + Velocity Vectors on live feed
