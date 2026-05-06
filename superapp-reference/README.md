# Superapp reference hub

## Desktop bundle (Windsurf only sees `~/Desktop`)

A **full copy** that lives on your Mac Desktop — **point Windsurf / Superapp at:**

`/Users/elijahbonds/Desktop/FEL-Superapp-Reference`

Refresh it after editing docs here:

```bash
./scripts/sync_superapp_desktop.sh
```

Desktop-only entry files (`START_HERE.md`, `REPOSITORY_ROOT.txt`, absolute-path `MANIFEST.json`, README header) live under **`superapp-reference/desktop-bundle/`** in the repo.

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
| [`DISTRIBUTION_SUPERAPP.md`](./DISTRIBUTION_SUPERAPP.md) | App Store Connect / TestFlight + how Superapp should consume releases |
| [`LOCAL_AND_SECRET_POINTER.template.md`](./LOCAL_AND_SECRET_POINTER.template.md) | Copy to `LOCAL_AND_SECRET_POINTER.md` (gitignored) — UE path, Team ID, ASC IDs |

## Quick orientation

- **Integration branch:** `setup-healthkit` (not `main` for handoff unless explicitly merged).
- **Product shape:** Unreal Engine **host** iOS app + **WKWebView** overlay dashboard; **`finalevolution://`** deep links; optional **HealthKit** in Swift shell; distribution via **App Store Connect / TestFlight** (no third-party store feeds in repo).
- **Blindness fix:** If a tool “can’t see” the app, point it at **`MANIFEST.json`** and the linked paths—those files are the contract for what exists in-repo vs on-disk outside the clone.
