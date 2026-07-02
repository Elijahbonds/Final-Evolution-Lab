# Final Evolution Lab — PRD

## Vision
Athlete-first training platform: digital avatar, PRQ-oriented performance modeling, health data, and periodized workouts unified into one "system scan" view. Creator Cards power a marketplace feeding live game modes (UE5.7) across venues and sports. A coach/critique economy aligns incentives with quality feedback. Education spans Brain Brawl (cognitive), Common Core through college prep, STEM, and a certificate program in applied kinesiology — linking academic rigor with athletic performance.

## FEL OS Architecture (Master Directive — Feb 2026)
Four pillars unified into a single dashboard:
1. **SCAN** — PRQ + 8 biomechanical metrics + streak + last vertical jump
2. **CARDS** — Creator Card portfolio + lifetime purchases (PayPal sandbox)
3. **ARENA** — 19 UE5 game modes + vault sessions + iOS deep-link bridge
4. **ACADEMY** — 4 education tracks (24 lessons total + 10-question final)

### Education Tracks (auto-graded quizzes)
| Track | Lessons | Pass | XP/lesson |
|---|---|---|---|
| Common Core Pathway | 6 | 75% | 50 |
| STEM in Sports Science | 6 | 75% | 50 |
| Applied Kinesiology Certificate | 8 + final | 75% / 80% | 50 + 1000 |
| Brain Brawl Arena | 4 (briefings only) | 75% | 50 |

### Applied Kinesiology Certificate — 4 gates required:
1. All 8 coursework lessons passed (≥75%)
2. All 4 Bio-Digital anatomy modules mastered (skeletal_basics, muscular_chains, kinetic_chain_pillars, neural_priming)
3. PRQ score ≥ 80
4. Final assessment passed (≥80% on 10 questions)

### Brain Brawl
Web exposes briefings/cooldowns. Live gameplay launches via `finalevolution://brain-brawl/launch` deep link to the iOS-wrapped UE5 binary.

## Architecture
```
/app/
├── backend/
│   ├── core.py                 # User, db, get_current_user, EMERGENT_KEY (NEW)
│   ├── server.py               # FastAPI monolith (still ~2400 LOC; uses core)
│   ├── routers/
│   │   ├── education_tracks.py # 4 tracks, 24 lessons, final, kinesiology cert
│   │   └── system_scan.py      # /api/system-scan/unified
│   └── tests/
│       └── test_fel_os_education.py  # 26 tests (NEW)
├── frontend/src/
│   ├── App.js                  # FEL OS = default tab
│   └── components/
│       ├── FELOSDashboard.js   # 4-quadrant + TrackDetail + LessonRunner + KinesiologyFinal (NEW)
│       ├── NewViews.js
│       ├── QualityGates.js
│       └── SovereignDashboard.js
└── infra/
    ├── ue5_config/
    └── native_ios/FELNativeSwiftBridge.swift
```

## Key API Endpoints (FEL OS additions)
- `GET  /api/education/tracks` — list 4 tracks
- `GET  /api/education/tracks/{track_id}` — track + lessons (no answers)
- `GET  /api/education/tracks/{track_id}/lesson/{lesson_id}` — quiz (answers stripped)
- `POST /api/education/tracks/{track_id}/lesson/{lesson_id}/submit` — auto-grade + XP
- `GET  /api/education/progress` — user progress across all tracks
- `GET  /api/education/kinesiology/eligibility` — 4-gate eligibility report
- `GET  /api/education/kinesiology/final-assessment` — 10 Q final
- `POST /api/education/kinesiology/final-assessment/submit` — auto-grade
- `POST /api/education/kinesiology/certify` — issues `FEL-AK-XXXXXXXXXX` cert + 1000 XP (idempotent)
- `POST /api/education/bio-digital/complete-module` — mark anatomy module mastered
- `POST /api/education/brain-brawl/launch` — returns UE5 deep link
- `GET  /api/system-scan/unified` — 4-quadrant snapshot {scan, cards, arena, academy}

(Existing endpoints preserved: auth, PayPal, vault WS, bio-digital overlay, registry/venues, multiplayer, referral, analytics, production/health, root /health.)

## Tech Stack
- React 19, FastAPI, MongoDB, Motor
- Lucide icons, shadcn/ui
- WebSockets for live telemetry (Vault Hub at `wss://finalevolutiongroup.com/ws/vault`)
- PayPal SDK (sandbox)
- Native iOS wrapper + UE5.7 deep linking (`finalevolution://`)
- Emergent LLM key for AI Coach

## Testing Status
- Iteration 7 (Feb 2026): 26/26 backend tests pass; full frontend FEL OS flow verified — 0 issues.
- Test sessions in `/app/memory/test_credentials.md`.

## Backlog
### P0
- iOS shipping package: `./fel_ue5_ios_shipping_package.sh --shipping`
### P1
- Full server.py refactor — break remaining ~2,400 LOC into routers/{auth,games,marketplace,vault,bio_digital,social,analytics}.py
- Add unique compound index on `(education_progress.user_id, track_id)` to harden cert idempotency
- Cooldown/TTL on `brain_brawl_launches` collection
### P2
- Auth gating on lesson detail endpoint (currently public; answers are stripped so low risk)
- Brain Brawl live web preview (cognitive mini-game in browser as fallback when iOS not available)
- Track-specific certificates for Common Core / STEM (currently only kinesiology issues a credential)
- Localization of lesson content
