# Final Evolution Lab - PRD

## NATIVE iOS DEPLOYMENT — Local Sovereign

### Deep Link Playability
- All 17 modes mapped: `finalevolution://launch?map={venue}&mode={mode_id}&session={session_id}`
- 12 production + 5 staging modes
- Deep link → UE5 12-Mode Manager → Map loads → ws://localhost:8888 tracks session
- Session state: launching → map_loading → active → completed
- Score flows: Session complete → PRQ recalculate → Referral chain → MongoDB

### Two-App System (iPhone 16 Pro Max)
1. **Final Evolution Lab** — UE5 high-fidelity game (the Players)
2. **Sovereign Dashboard** — Mobile shell (the Stadium)
- "Start Training" → deep link → UE5 launches map → Mac Mini starts PRQ clock

### Mobile Shell Config
- Bundle: com.finalevolutionlab.sovereign
- Permissions: LiDAR, Motion, Camera, Local Network
- Sensors: depth_map, point_cloud, accelerometer, gyroscope, body_tracking
- Hub: ws://localhost:8888 via Cloudflare tunnel

### Sovereign Hub
- Cloud: DISABLED | Video: DISABLED | E3DS: BYPASSED
- Data feed: Biomechanical (LIVE from bridge)
- PRQ: Local MongoDB (weighted_composite, NOT simulation)
- Encryption: AES-256-GCM

### How to Play
1. Tap Zen Dojo → Emergent Shell sends deep link
2. UE5 switches to /Game/FEL/Maps/Zen_Dojo
3. Mac Mini starts PRQ clock via Sovereign Hub
4. Score/PRQ/biomechanical data flows in real-time
