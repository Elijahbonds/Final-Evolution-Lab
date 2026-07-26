# Embedded Unreal framework (Swift container)

Place the Unreal **library / framework** output here so Xcode can copy it into `FinalEvolutionLab.app/Frameworks/` on each build:

```
FinalEvolutionLab/EmbeddedFrameworks/UnrealFramework.framework
```

## UE export expectations

- The Swift shell’s `UnrealManager` loads **`UnrealFramework.framework`** from **`Bundle.main.privateFrameworksPath`** (i.e. the app’s `Frameworks` directory).
- The framework’s **principal class** must expose Objective‑C selectors: `getInstance`, `runEmbedded`, `unloadApplication`, and `rootView` (same pattern as the legacy `UnityManager` stub).

Rename your UE-produced framework to **`UnrealFramework.framework`** if Epic’s export uses a different product name, **or** change `UnrealManager.swift` to match the on-disk name.

## Build pipeline

1. Build the UE iOS target that produces an embeddable framework (project-specific; often “UE as a library” or a custom Xcode target).
2. Copy the resulting `.framework` into this folder.
3. Build **`FinalEvolutionLab.xcodeproj`** — the **Embed Unreal Framework (optional)** run script copies and code-signs when the framework exists.

This directory is safe to leave empty during day-to-day Swift-only development; the Unreal UI shows a placeholder until the framework is present.
