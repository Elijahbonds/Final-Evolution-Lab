# “Platform Mac is not a valid platform” / “could not be compiled” (UE 5.2 on Mac)

Epic’s generic message is **misleading**. The real reason is in the UnrealBuildTool log.

---

## 1. Confirm the real error (do this first)

Run a build with **`-verbose`**:

```bash
"/Users/Shared/Epic Games/UE_5.2/Engine/Build/BatchFiles/Mac/Build.sh" MyProject3Editor Mac Development \
  -Project="/path/to/MyProject3.uproject" -verbose
```

Then open:

`~/Library/Application Support/Epic/UnrealBuildTool/Log.txt`

### A) Xcode / Mac SDK too new for UE 5.2 (very common on current Macs)

If you see a line like:

```text
Unable to find valid SDK(s) for Mac: Found Sdk Version: 26.3. MinRequired=14.1.0, MaxRequired=15.9.9
```

then **Unreal 5.2 refuses your Xcode**: it only accepts a Mac SDK up to **15.9.x**. **Xcode 26** (and other versions above that range) are **intentionally rejected**, so **Mac is `buildable: False`** and the editor says **rebuild from source** / **could not be compiled**.

**Fixes (pick one):**

| Approach | What to do |
|----------|------------|
| **Recommended** | Install a **newer Unreal** (e.g. **5.4+** or latest **5.x** from Epic Launcher) that officially supports your **Xcode** version, and open the same project (upgrade copy when prompted). |
| **Stay on UE 5.2** | Install **Xcode 15.x** (or any Xcode whose reported SDK is **≤ 15.9.9**) **side‑by‑side** (e.g. rename to `Xcode_15.app`), then point the toolchain at it: `sudo xcode-select -s /Applications/Xcode_15.app/Contents/Developer` — confirm with `xcodebuild -version`. |
| **Blueprint-only** | Not a compile fix: create a **Blueprint** project without C++ so the editor doesn’t need UBT for your game code (you still need a valid Mac toolchain for engine modules in some workflows). |

**“Rebuild from source manually”** in the editor does **not** bypass this: **Xcode must fall in UE’s allowed range** (or you must use a **newer engine**).

### B) Incomplete engine install (less common)

If **`Engine/Platforms`** under your UE install has **no `Mac`** folder (only e.g. **HoloLens**), the install may be damaged.

```bash
ls "/Users/Shared/Epic Games/UE_5.2/Engine/Platforms/"
```

A normal Mac editor layout includes **`Mac`**. If it’s missing: Epic Launcher → **Library** → **5.2** → **⋮** → **Verify** (or reinstall).

---

## 2. Xcode basics (after SDK version is acceptable)

1. Full **Xcode** from the App Store (not only Command Line Tools for full editor builds).
2. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (or your **15.x** app path).
3. Open **Xcode** once; if needed: `sudo xcodebuild -license accept`.
4. **Xcode → Settings → Locations → Command Line Tools** → select that Xcode.

---

## 3. Summary

| Log clue | Cause | Action |
|----------|--------|--------|
| `Found Sdk Version: 26.x` / `MaxRequired=15.9.9` | **Xcode too new for UE 5.2** | Newer **UE** or older **Xcode** + `xcode-select` |
| No **`Platforms/Mac`** | Broken/partial engine | **Verify** / reinstall **UE 5.2** in Launcher |

Log file: **`~/Library/Application Support/Epic/UnrealBuildTool/Log.txt`**

---

*Final Evolution Lab — UnrealStarter troubleshooting.*
