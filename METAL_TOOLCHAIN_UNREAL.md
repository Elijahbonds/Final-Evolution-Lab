# Download Metal Toolchain (for Unreal / Apple)

The **Metal toolchain** is required for building and compiling Metal shaders when targeting **iOS**, **macOS**, or **tvOS** — including Unreal Engine projects that run on Apple platforms.

---

## Option 1: Xcode (easiest)

1. Open **Xcode**.
2. **Xcode → Settings…** (or **Preferences** on older versions).
3. Go to the **Platforms** or **Components** tab (name varies by Xcode version).
4. Find **Metal Toolchain** and click **Get** / **Download**.

---

## Option 2: Command line

From Terminal (requires Apple ID / Xcode to be set up):

```bash
xcodebuild -downloadComponent MetalToolchain
```

Optional: export to a folder (e.g. to share or backup):

```bash
xcodebuild -downloadComponent MetalToolchain -exportPath ~/Desktop/MetalToolchainExport
```

Check if it’s already installed:

```bash
xcodebuild -showComponent MetalToolchain
```

---

## For Unreal Engine on Mac

- Unreal uses the **Metal toolchain** that comes with (or is downloaded into) **Xcode**.
- Ensure **Xcode** is installed and the **command line tools** are selected: **Xcode → Settings → Locations → Command Line Tools**.
- After downloading the Metal toolchain, **restart Xcode** (and Unreal if it’s open), then build your Unreal project for iOS or macOS.

---

## If you develop on Windows but target Apple

Apple provides **Metal Developer Tools for Windows** so you can build Metal shaders/assets for iOS/macOS from a Windows machine:

- **Download:** [Apple Developer – Metal Developer Tools for Windows](https://developer.apple.com/download/all/?q=metal%20developer%20tools%20for%20windows)
- Requires an Apple Developer account (free or paid).

---

## Troubleshooting

- **“MetalToolchain build failed”** (e.g. on some Xcode 26 betas): Install the latest **Metal Toolchain** from Xcode Settings → Components, or try a different Xcode version.
- **Unreal can’t find Metal**: Point Unreal to your Xcode install (Editor Preferences or project settings for Apple platforms). The Metal toolchain is used by Xcode’s build system; Unreal invokes it when building for Apple.
- **`posix_spawn() failed (86, Bad CPU type in executable)`** with **`IOSTargetPlatform`** / **`QueryDevices`**: Wrong CPU architecture for a child process (common on **Apple Silicon** with UE **5.2** or mixed arm64/x64 tools). See **`UnrealStarter/MAC_IOS_BAD_CPU_SPAWN.md`**.
