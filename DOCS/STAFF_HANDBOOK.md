# Final Evolution LLC — Staff Handbook

**Audience:** Staff onboarding, arena operators, and coaches running athlete sessions.  
**Companion docs:** `GAMEPLAY_STATUS.md` (product/gameplay scope), Arena implementation (Neuro-Mechanic + Unreal bridge).

### From `GAMEPLAY_STATUS.md` — current shell (authoritative gameplay summary)

- **Arena** = venue list → pick mode → **Get Ready** → **Play** → **Result** (two play paths: Brain Brawl vs generic arena modes).  
- **Lab** = freestyle Dunk Contest (RealityKit) — separate from Arena’s generic tap-to-commit flow for most modes.  
- **Local Play** = Multipeer lobby; same generic arena shell with P1/P2 sync.  
- **DDA / PRQ** = difficulty and scoring weight per mode; results feed shards + PRQ on the result screen.

Staff should treat `GAMEPLAY_STATUS.md` as the **gameplay** source of truth; this handbook covers **operations** (Neuro-Mechanic, streaming, latency, rostering, hero clips).

---

## 1. Neuro-Mechanic workflow

Neuro-Mechanic governs how **readiness data** flows from the iOS shell to Unreal (`readiness_snapshot.json` → `FELReadinessIO`).

### Forensic Mode (production calibration)

- **Purpose:** Legitimate biomechanical capture and PRQ alignment for AvatarRigBuilder / System Scan.
- **Lighting gate:** Arena **luminance** must stay above the forensic threshold so pose and readiness export are trustworthy. Staff should treat **average ambient luma ≥ 0.3** (see `FELLuminanceAnalyzer` / `felNeuroMechanicLightingOptimal`) as **optimal** for export.
- **Behavior:** When lighting is **below** optimal, `PRQManager` **does not** write `readiness_snapshot.json` (forensic integrity — avoid garbage-in to Unreal). Coaches see the forensic pause overlay until the athlete moves to adequate light.

### Demo Mode (showcase / Fast-Track)

- **Purpose:** Repeatable demos without re-filming a jump every time.
- **Toggle:** **Settings → Demo Mode** (`felDemoModeShowcase`).
- **Behavior:** **System Scan** exposes **FAST-TRACK — CACHED AVATAR RIG**, reusing the last cached scan / rig scales for instant handoff. Use for **floor demos only**, not for athlete assessment sign-off.

**Rule of thumb:** Forensic = measurable truth. Demo = speed and spectacle.

---

## 2. Pixel Streaming setup (showcase lane)

**Goal:** Stream the Unreal arena from a **Mac mini M4 Pro** host to a **PS5 browser** client at **1080p / 60 fps** for staff-led demos.

| Role | Responsibility |
|------|----------------|
| **Host (Mac mini)** | Run the Unreal packaged build with Pixel Streaming plugin + Signaling/Web server; GPU encodes the stream (see Epic Pixel Streaming docs for NVENC/AMF). |
| **Client (PS5)** | Open the Pixel Streaming **player** URL in the browser; use a wired or low-latency LAN. |

**Merge config:** `UnrealStarter/BasketballGame/CONFIG_DefaultEngine_FEL.ini` includes WebRTC FPS and degradation hints; **also** launch with explicit resolution, e.g.:

`-PixelStreamingURL="ws://<host-ip>:8888" -ResX=1920 -ResY=1080 -ForceRes`

**Note:** Epic’s Pixel Streaming reference historically targets **Windows/Linux** hosts for the full stack; validate encoder paths on Apple Silicon if you rely on this repo’s merge snippets. Adjust firewall ports (default signaling **8888**, HTTP **80**/HTTPS **443** per Epic docs).

---

## 3. Hardware health — 16.6 ms latency HUD

**Why 16.6 ms:** One frame at **60 Hz** ≈ **16.67 ms**. Input-to-simulation latency above that shows up as sluggish jumps and missed Bonds Apex timing in arena review.

| Signal | Source | Staff action |
|--------|--------|--------------|
| **Latency HUD (DA build)** | Unreal `InputLatencyMonitor` → `felInputLatencyJumpMsSample` → Arena **FEL_NON_SHIPPING** overlay | If samples **exceed ~16.6 ms** consistently, check controller/BT, background load, thermal throttling, or embedded viewport vs full-screen. |
| **Twin scales debug** | `PRQManager` / `felReadinessTwinScalesUpdated` | Confirms `avatarHeightScale` / `avatarWeightScale` match the last JSON export after sync. |

Treat the HUD as a **health check**, not a marketing number: fix regressions before recording athlete-facing content.

---

## 4. Multi-athlete operations

- **Switching athletes:** Use `PRQManager.switchAthleteProfile(newProfile:)` so local readiness artifacts reset, JSON is regenerated for the active athlete, and Unreal receives a fresh **setUnrealReady**-style handshake (see code). Always confirm **Active Athlete** on the Arena ribbon matches the person on the floor.

---

## 5. Hero clips (social / viral)

- **Trigger:** Unreal posts **`felHeroMomentExportReady`** when a **Bonds Apex** demo replay window (≥ ~40" estimated apex, Venice path) starts.
- **Capture:** The shell uses **ReplayKit** (`RPScreenRecorder`) to record **3.5 seconds** from **Download Hero Clip** and save to **Photos** (`NSScreenCaptureUsageDescription` + existing photo-library add strings in the Xcode target).
- **Staff tip:** ReplayKit records **forward** from the tap — have the athlete or operator tap **immediately** when the Sonic Flare / mirror beat begins so the clip lines up with the hero window.

---

## 6. Reference map

| Topic | Doc / code |
|-------|------------|
| Arena shell, modes, generic play | `GAMEPLAY_STATUS.md` |
| Readiness JSON keys | `FelReadinessSnapshotExport` in `PRQManager.swift` |
| Unreal gameplay audit | `UnrealStarter/BasketballGame/QA_GAMEPLAY_AUDIT.md` |
| Nintendo Switch strategy (Global Expansion 1.0.0) | `DOCS/NINTENDO_DEV_PITCH.md` |

*Final Evolution LLC — internal use.*
