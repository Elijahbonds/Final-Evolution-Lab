# Phase 3 — Unreal iOS package + SceneKit Release smoke

**Goal:** Two shippable artifacts on the same **device OS class** (e.g. iOS 18+): the **Unreal** `FinalEvolutionLab` iOS build and the **Swift/SceneKit** `FinalEvolutionLab` app — both build cleanly before device install and manual QA.

---

## 1. Unreal — compile matrix (Mac)

Fast loop (skips iOS UBT probe):

```bash
VERIFY_FEL_SKIP_IOS=1 bash UnrealStarter/scripts/verify_fel_build_matrix.sh
```

Full matrix (includes `check_fel_ios_engine.sh`):

```bash
bash UnrealStarter/scripts/verify_fel_build_matrix.sh
```

---

## 2. Unreal — iOS package (RunUAT)

Requires **UE 5.7** with **iOS** target platform installed (`Epic Games Launcher` → Engine → Options).

```bash
bash UnrealStarter/scripts/package_fel_ios.sh
```

Output defaults to `UnrealStarter/BasketballGame/Saved/Archive/IOS_Development/`. Then open the generated Xcode workspace (`open_fel_ios_xcode.sh` after a cook) or follow `UnrealStarter/RUN_UNREAL_ON_IPHONE_XCODE.md`, set **Team**, install on device, confirm **VeniceBeach** (or your `GameDefaultMap`) loads.

---

## 3. SceneKit shell — Release build (no signing required for compile check)

From repo root:

```bash
cd ios && xcodebuild -scheme FinalEvolutionLab -configuration Release \
  -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```

For a **signed** install to a named device, use Xcode (⌘R) or archive with your provisioning profile.

---

## 4. One-shot automation (repo)

```bash
bash UnrealStarter/scripts/verify_fel_phase3_smoke.sh
```

Optional: also run the Unreal matrix (adds several minutes):

```bash
VERIFY_FEL_PHASE3_UE_MATRIX=1 bash UnrealStarter/scripts/verify_fel_phase3_smoke.sh
```

---

## Phase 3 exit criteria

- [ ] `verify_fel_phase3_smoke.sh` succeeds (or manual steps 1–3 above).
- [ ] **Device:** install UE `.ipa` / Xcode run — default map + one arena mode loads (manual).
- [ ] **SceneKit:** Release `.app` builds; on-device smoke is optional for Phase 3 sign-off if CI only compiles.

*See:* `DOCS/FEL_UNREAL_AND_SCENKIT_10_PHASE_PASS.md` — Phase 3.
