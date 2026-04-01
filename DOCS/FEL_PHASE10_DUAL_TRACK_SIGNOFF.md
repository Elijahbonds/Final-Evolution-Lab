# Phase 10 — Dual-track sign-off (Unreal + SceneKit)

**Goal:** Ship-quality confidence on **both** the canonical Unreal client and the legacy SceneKit lab, using automated static checks plus a short **manual** device/content pass.

**Not** the same as Gold Master Mac packaging (`Content/FEL/Venues/GOLD_MASTER_MAC_PACKAGING.txt`).

---

## 1. Automated (repo root)

**Full static chain (Phase 2–8 + Phase 10 inventory, no compile):**

```bash
chmod +x UnrealStarter/scripts/verify_fel_phase10_dual_track_static.sh
bash UnrealStarter/scripts/verify_fel_phase10_dual_track_static.sh
```

**Optional — Unreal Editor + game compile + iOS unit tests (macOS, slower):**

```bash
bash UnrealStarter/scripts/verify_fel_phase9_automation.sh
VERIFY_FEL_PHASE9_UE_MATRIX=1 bash UnrealStarter/scripts/verify_fel_phase9_automation.sh
```

**Compile Unreal only:**

```bash
VERIFY_FEL_SKIP_IOS=1 bash UnrealStarter/scripts/verify_fel_phase10_signoff.sh --compile
```

---

## 2. Manual — device matrix

| Build | Device 1 | Device 2 | iPad (optional) | Pass / notes |
|-------|----------|----------|-----------------|--------------|
| **Unreal iOS** (packaged per `RUN_UNREAL_ON_IPHONE_XCODE.md`) | | | | |
| **SceneKit** (`ios/FinalEvolutionLab`, Release or TestFlight) | | | | |

Minimum suggested: **two iPhones** + **one iPad** class device across the two rows (adjust for your lab).

---

## 3. Manual — content / quality

| Check | Unreal | SceneKit |
|-------|--------|----------|
| **Luma / Sovereign Shop** visible or reachable in UE (`market_browse` / `Luma_Venice_Shop` per `ArenaSettings.json`) | ☐ | N/A |
| **Venice / arena** playable default map; no black screen | ☐ | N/A |
| **Arena scale / readability** (Phase 5 bar) | Match in-editor if tuning | ☐ `ArenaSceneConfig` courts feel usable |

---

## 4. Release bookkeeping

- [ ] **Changelog:** add a line under `DOCS/CHANGELOG_FEL_DUAL_TRACK.md` (or your product changelog) for this release.
- [ ] **Git tag (optional):** `fel-dual-pass-10` on the signed-off commit.

```bash
git tag -a fel-dual-pass-10 -m "FEL dual-track Phase 10 sign-off"
```

---

*FEL — dual-track 10-phase pass.*
