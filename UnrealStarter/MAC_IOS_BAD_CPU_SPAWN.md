# Unreal on Mac: `posix_spawn() failed (86, Bad CPU type in executable)` (iOS device query)

## What the crash means

- **`EpicAccountId:…`** in the log is your Epic account id from telemetry — **not** the cause of the crash.
- **`FMacPlatformProcess::CreateProc: posix_spawn() failed (86, Bad CPU type in executable)`** means macOS refused to start a **child program** because that binary’s **CPU architecture** doesn’t match a runnable architecture on your Mac (or Rosetta isn’t available for an Intel-only helper).
- The stack shows **`UnrealEditor-IOSTargetPlatform`** → **`FDeviceQueryTask::QueryDevices`**: the editor is trying to run a **tool used to discover iOS devices** (or a related Apple CLI), and that executable is the wrong arch for your machine.

This is common on **Apple Silicon (M1/M2/M3/…)** with **older UE builds** (e.g. **5.2**) that still ship or invoke **Intel-only** helpers, or when **mixed** arm64/x86_64 tools are on your `PATH`.

---

## Fix (try in order)

### 1. Install Rosetta 2 (Apple Silicon only)

If Rosetta isn’t installed, **Intel-only** helpers cannot run.

```bash
softwareupdate --install-rosetta --agree-to-license
```

Quit Unreal completely, reopen, and retry. If the editor itself is Intel-only, run it under Rosetta (Finder → **Unreal Editor.app** → **Get Info** → **Open using Rosetta**) so spawned children match the same environment.

### 2. Match the editor to your Mac

- Prefer an **Apple Silicon (native)** Unreal build from the Epic Launcher when you’re on **arm64**.
- Check what you’re actually running:

```bash
file "$HOME/Shared/Epic Games/UE_5.2/Engine/Binaries/Mac/UnrealEditor" 2>/dev/null
# or wherever your engine lives:
# file "/path/to/UnrealEditor.app/Contents/MacOS/UnrealEditor"
```

You want **arm64** (or **universal** with arm64) on an Apple Silicon Mac. If you only have **x86_64**, use **Rosetta** for the whole editor (step 1 + “Open using Rosetta”) or install a build that includes arm64.

### 3. Fix wrong-arch CLI tools on `PATH`

Device discovery often shells out to Apple/Xcode tools or third-party binaries (e.g. **`ios-deploy`** from Homebrew/npm). A stray **x86_64-only** binary on an **arm64** Mac (or the reverse on Intel) triggers this error.

```bash
which ios-deploy 2>/dev/null
file "$(which ios-deploy)" 2>/dev/null
```

If `file` shows an arch your machine can’t run, reinstall for your arch (e.g. native **arm64** Homebrew, or `brew reinstall ios-deploy`), or remove the broken path from your shell profile so Unreal doesn’t pick it up.

Ensure **Xcode** is installed and active:

```bash
xcode-select -p
xcodebuild -version
```

### 4. Newer engine minor (recommended for Apple Silicon + iOS)

UE **5.2** predates a lot of Apple Silicon polish. If you can move the project to a **newer 5.x** (5.3+), iOS platform tooling and bundled helpers are generally more reliable on **arm64** Macs.

### 5. Work around: Mac-only work without iOS device scan

If you only need **Editor on Mac** and **not** iOS packaging right now, avoid flows that **enumerate iOS devices** (e.g. some **Platforms → iOS** / **Launch** dialogs). That may still run in the background on some builds; if the editor crashes on startup, steps **1–4** are the real fix.

---

## Quick checklist

| Check | Action |
|--------|--------|
| Apple Silicon + “Bad CPU type” | Install **Rosetta**; align **UnrealEditor** arch with **arm64** or run editor with Rosetta |
| `ios-deploy` / other CLIs | `file $(which ios-deploy)` — must be runnable on your CPU |
| Old UE 5.2 | Consider **5.3+** for better arm64 iOS support |
| Xcode | Full **Xcode** + correct **Command Line Tools** in Xcode **Settings → Locations** |

---

*Final Evolution Lab — UnrealStarter troubleshooting for Mac + iOS target platform.*
