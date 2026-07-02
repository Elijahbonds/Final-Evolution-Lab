# Release reference hub

**Desktop location (point Windsurf / agents here):**  
`/Users/elijahbonds/Desktop/FEL-Release-Reference`

**Git repo clone (all source code):** see **`REPOSITORY_ROOT.txt`** in this folder — open files there for implementation work.

Start with **`START_HERE.md`**, then **`MANIFEST.json`** (includes absolute paths into the repo).

---

**Read this folder first** before changing distribution, iOS/Unreal packaging, or backend contracts. Everything here is plain text so agents and humans can load context without guessing.

| Doc | Purpose |
|-----|---------|
| [`MANIFEST.json`](./MANIFEST.json) | Machine-readable index of critical paths + tags |
| [`INTEGRATION_BRANCH.md`](./INTEGRATION_BRANCH.md) | Canonical Git branch and what not to merge |
| [`PRODUCT_ONE_PAGE.md`](./PRODUCT_ONE_PAGE.md) | What Final Evolution Lab *is* (architecture + surfaces) |
| [`REPOSITORY_MAP.md`](./REPOSITORY_MAP.md) | Top-level map of this repo (“whole app” orientation) |
| [`IOS_UNREAL_PIPE.md`](./IOS_UNREAL_PIPE.md) | Shipping script, archive/export, cooked payload / descriptor safety |
| [`BACKEND_AND_WEB_SURFACES.md`](./BACKEND_AND_WEB_SURFACES.md) | API/backend + dashboard frontend touchpoints |
| [`SWIFT_IOS_SHELL.md`](./SWIFT_IOS_SHELL.md) | Native Swift app folder (HealthKit, etc.) |
| [`DISTRIBUTION_CANONICAL.md`](./DISTRIBUTION_CANONICAL.md) | App Store Connect / TestFlight + official release metadata |
| [`LOCAL_AND_SECRET_POINTER.template.md`](./LOCAL_AND_SECRET_POINTER.template.md) | Copy to `LOCAL_AND_SECRET_POINTER.md` (gitignored) — UE path, Team ID, ASC IDs |

## Quick orientation

- **Integration branch:** `setup-healthkit` (not `main` for handoff unless explicitly merged).
- **Product shape:** Unreal Engine **host** iOS app + **WKWebView** overlay dashboard; **`finalevolution://`** deep links; optional **HealthKit** in Swift shell; distribution via **App Store Connect / TestFlight** (no third-party store feeds in repo).
- **Blindness fix:** If a tool “can’t see” the app, point it at **`MANIFEST.json`** and the linked **`absolute_path`** entries — use **`REPOSITORY_ROOT.txt`** to open the clone.
