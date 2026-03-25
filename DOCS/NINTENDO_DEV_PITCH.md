# Final Evolution 1.0.0 — Nintendo Developer Pitch & Platform Strategy

**Audience:** Nintendo developer relations, technical evaluators, and first-party production partners.  
**Cross-reference:** `DOCS/STAFF_HANDBOOK.md` (operations + Neuro-Mechanic integrity), UE 5.7 migration notes (forward mobile path, scalability), and `UFELPlatformManager` / `Config/Switch/` for shipped cvars.

---

## Executive summary

**Final Evolution** positions Nintendo Switch as a **portable Neuro-Mechanic lab**: the same readiness pipeline that powers iOS (`readiness_snapshot.json` → Unreal `FELReadinessIO`) runs on Switch, while **Joy-Con HD Rumble** and **Active Performance** feedback turn abstract PRQ and Bonds Apex moments into **felt** biomechanical truth—aligned with Staff Handbook rules on forensic lighting, 16.6 ms frame health, and hero-clip windows.

---

## Pillar 1 — Active Performance & Joy-Con biometrics

### Active Performance

- **Neuro-Mechanic loop (Staff Handbook §1):** Forensic readiness export requires trustworthy ambient light; on Switch we preserve the **same semantic contract**—Arena luminance gating maps to mobile forward shading and baked shop lighting so frame budget stays predictable for **60 FPS** in portable mode.
- **16.6 ms discipline (Staff Handbook §3):** One frame at 60 Hz ≈ **16.67 ms**. Switch builds target **stable 60** in Luma Venice Shop and core arena shells; `UFELPlatformManager` applies Switch-specific **forward shading** and **scene color format** cvars to reduce overdraw and bandwidth (see `UFELPlatformManager::ApplySwitchSettings`).

### Joy-Con biometrics (differentiation)

- **Not medical claims:** Joy-Con inputs provide **high-resolution timing, impulse, and HD Rumble** channels—not clinical vitals. Positioned as **player-facing “kinetic truth”**: gather tension, apex commit (Bonds Apex ≥ ~40"), and Sonic Flare bloom are mirrored in **dual-motor rumble** (`AFELBasketballCharacter::TriggerSwitchHaptics`), reinforcing the same “measure you” pillar as iOS haptics and PS5 adaptive triggers.

---

## Pillar 2 — Switch as a portable Neuro-Mechanic lab

- **Same 1.0.0 product spine:** Games → Lab → Arena → Train → Fuel → Status → Film → Stream → Profile; **readiness JSON** and arena mode handshake match iOS and PS5 (see `STAFF_HANDBOOK` reference map).
- **Portable use case:** Athletes and coaches can run **session review, shop flows (Luma Venice), and arena rehearsal** docked or handheld without compromising the **forensic vs demo** split described in the handbook.

---

## Pillar 3 — Switch Lite & Luma Venice Shop rendering strategy

### Targets

| Mode | FPS target | Rendering strategy |
|------|------------|----------------------|
| **Switch / Switch Lite (portable)** | **60 FPS** | **Forward shading** (`r.Mobile.ForwardShading 1`), **fixed scene color** (`r.Mobile.SceneColorFormat 0`), **baked / static lighting** bias in Luma Venice Shop to avoid dynamic GI spikes. |
| **Docked** | 60 FPS (quality bar) | Same scalability tier; optional resolution scale via `DefaultScalability.ini` groups. |

### Luma Venice Shop (Bonds Apex & mirror floor)

- **Staff Handbook alignment:** Hero clips and ReplayKit on iOS; on Switch, **TV-style broadcast windows** and Sonic Flare remain **time-dilated** only inside validated shop maps—engine cvars and scalability prevent VRAM overshoot on **4 GB** class devices.
- **Switch Lite:** No dynamic resolution to a second screen; prioritize **stable frame time** over shader feature count—**no ray tracing**, texture footprint clamped (see `Config/Switch/DefaultScalability.ini`).

---

## Technical appendix (code pointers)

| Topic | Location |
|--------|----------|
| Switch cvars at boot | `UFELPlatformManager::ApplySwitchSettings` |
| Switch scalability | `Config/Switch/DefaultScalability.ini` |
| Joy-Con rumble: Bonds Apex + Sonic Flare | `AFELBasketballCharacter::TriggerSwitchHaptics` |
| Readiness JSON | `FELReadinessIO`, `PRQManager.swift` (iOS shell) |

---

## Closing ask

We seek Nintendo partnership for **1.0.0 Global Expansion**: **Switch (portable Neuro-Mechanic lab)**, **PS5 (high-end PSSR / TSR paths)**, and **iOS (forensic + Metal)** sharing one Unreal 5.7 codebase—with platform managers and config proving **VRAM-stable 60 FPS** and **HD Rumble** as first-class pillars.

*Final Evolution LLC — Nintendo-facing strategy draft. Align with `STAFF_HANDBOOK.md` for operational truth vs marketing.*
