# Migration Architect — Pivot to Unity (iOS) + UaaL

Use this as a **Composer prompt** or engineering brief. It complements **`UNREAL_ONLY.md`**; if you commit to Unity for the 3D Skill Lab, treat UnrealStarter as **reference only** until you archive or remove it.

---

## 1. Environment setup (Terminal) — accurate steps

**Homebrew cannot install the Unity Editor with iOS modules in a single `brew install` line.** Standard flow:

1. Install **Unity Hub** via Homebrew:
   ```bash
   brew install --cask unity-hub
   ```
2. Open **Unity Hub**, sign in, install **Unity 2022.3 LTS** (or newer LTS you standardize on).
3. Add modules from Hub: **iOS Build Support**, **Mac Build Support** (IL2CPP/Mono per your template). Hub’s CLI (`hub`) can automate installs if you script with a personal license — see [Unity Hub CLI](https://docs.unity3d.com/hub/manual/HubCLI.html) for your team’s license type.

**Script template (human-in-the-loop after Hub is installed):** generate a `scripts/install_unity_hub.sh` that only runs `brew install --cask unity-hub` and prints next steps (Hub UI for editor + modules). Do not claim one-shot full editor+modules via brew unless you document license + `hub` flags.

---

## 2. Architecture: Unreal → Unity

- Map **Unreal Actors / C++** → **MonoBehaviours** / **ScriptableObjects** in Unity 2022.3+ LTS.
- **Neuro-Mechanic / PRQ** payloads: mirror JSON shapes your Swift app already exports (`UnityExportManifest`, `readiness_snapshot` for Unreal) in C# DTOs.
- **Film Vault (side‑by‑side video):** implement with **Unity VideoPlayer** (two players + shared normalized time / checkpoints). Swift UI remains the shell; optional second phase embeds Film in Unity only if product requires one surface.

---

## 3. Unity as a Library (UaaL) — Swift bridge

**This repo already has `FinalEvolutionLab/Services/UnityManager.swift`:** it loads `UnityFramework.framework`, runs embedded, and exposes `sendMessageToGO(_:method:message:)` plus `sendDataToUnity` (MotionReceiver).

**Convention for new messages:** add a single GameObject in Unity named **`FELBridge`** with **`FELBridge.cs`** (see **`Unity/Scripts/FELBridge.cs`** in this repo). Methods **`OnFilmVaultMessage`** / **`OnSkillLabMessage`** match `UnityManager.swift`. Parse JSON and post results back via `UnitySendMessage` to native (see Unity **UaaL** iOS docs).

Extended helpers on `UnityManager`: `sendFilmVaultCommand`, `sendSkillLabCommand`.

---

## 4. Build pipeline

- Add a **Unity** `PostProcessBuild` (iOS) script to set signing placeholders, embedded frameworks, and bitcode settings per Apple/Unity version.
- For overlays: URP + Canvas/Screen Space — **Overlay** mode for HUD; keep Film Vault decode work off the main thread where possible.

---

## 5. Composer task block (paste into Cursor)

```
Task: Migrate Final Evolution 3D Skill Lab from Unreal reference code to Unity 2022.3 LTS (URP), keep Swift shell in FinalEvolutionLabUnreal.

1) Add scripts/install_unity_hub.sh (brew cask unity-hub + documented Hub steps for iOS/Mac modules).

2) Create Unity/ folder with URP project template layout OR document external repo; add C# bridge class FELBridge receiving JSON from iOS.

3) Film Vault: Unity VideoPlayer dual sync prototype + message contract from Swift via UnityManager.sendFilmVaultCommand.

4) PostProcessBuild iOS: stub script with comments for team ID / frameworks.

5) Do not remove UnrealStarter/; add README note "superseded by Unity if migration completes."
```

---

*Swift `UnityManager` is already present — extend Unity side to match message contracts.*
