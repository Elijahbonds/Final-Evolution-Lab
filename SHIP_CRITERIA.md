# Final Evolution — Ship Criteria (Hybrid Phase C)

**Reference:** `PROJECT_AUDIT_AND_FINISH_PLAN.md`, `GAMEPLAY_IMPROVEMENTS_PLAN.md`, `GAMEPLAY_STATUS.md`  
**Bundle ID (frozen):** `com.finalevolution.FinalEvoAPP`  
**Marketing version:** `1.0.0` (see Xcode `MARKETING_VERSION`)

This document is the **single checklist** for a **1.0.0-ready hybrid** product: Swift shell + embedded Unreal viewport + RealityKit Lab, with shared readiness export (`readiness_snapshot.json`) and gold-master packaging (`scripts/package_gold_master.sh`).

---

## Gold Master status matrix

| Surface | Runtime | Role | Gold Master criteria | Status |
|--------|---------|------|----------------------|--------|
| **Arena (venues / modes)** | **UE5** (`UFELUnrealViewportContainer`, Unreal bridge) | Primary 3D sports slice; `setUnrealReady` handshake; mode export → `active_mode` | Cooked maps + `readiness_snapshot.json` consumed by `FELReadinessIO`; Luma Venice shop loads; PS5 Pro / iOS tiers per `UFELPlatformManager` | **In progress** — merge `UnrealStarter/` into shipping `.uproject`, device cook |
| **Brain Brawl** | **Swift** (`BrainBrawlPlayView`, curriculum quiz) | Full quiz loop; shards; no Unreal dependency | 5-question flow stable; content expandable; accessibility on choices | **Playable** — expand question bank per `GAMEPLAY_STATUS.md` |
| **Lab** | **RealityKit** (`RealityKitDunkView`, `DunkContestEngine`) | Freestyle dunk + scan-driven avatar | 60 fps target; dunk phases; `readiness_snapshot.json` written before Unreal handoff | **Playable** — optional Arena route for dunk parity |

**Legend:** *Playable* = shippable loop exists; *In progress* = pipeline or content merge outstanding; update this table when CI or `package_gold_master.sh` reports green.

---

## Hybrid integration checkpoints

1. **Readiness JSON** — `Documents/FEL/readiness_snapshot.json` includes `active_mode`, gear paths, and **avatar** scales (`avatarHeightScale` / `avatarWeightScale`) for Unreal skeletal mesh parity with Swift `AvatarSkinConfig`.
2. **Notifications** — `felReadinessExportDidUpdateNotification`, AI Coach / Universal Sync hooks (`FELBridgeNotifications`) verified on device after smoke install.
3. **Provisioning** — `NSCameraUsageDescription` / `NSMotionUsageDescription` present for System Scan + AI Coach (generated Info.plist keys in Xcode).

---

## How to refresh this doc

After each major milestone, update the **Status** column and add a row to your internal changelog. Optional: gate on `build/GOLD_MASTER_BUILD_REPORT.txt` from `package_gold_master.sh`.
