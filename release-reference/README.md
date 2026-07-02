# Release reference hub

## Desktop bundle (Windsurf only sees `~/Desktop`)

A **full copy** that lives on your Mac Desktop — **point Windsurf / agents at:**

`/Users/elijahbonds/Desktop/FEL-Release-Reference`

Refresh it after editing docs here:

```bash
./scripts/sync_release_desktop.sh
```

Desktop-only entry files (`START_HERE.md`, `REPOSITORY_ROOT.txt`, absolute-path `MANIFEST.json`, README header) live under **`release-reference/desktop-bundle/`** in the repo.

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
- **Blindness fix:** If a tool “can’t see” the app, point it at **`MANIFEST.json`** and the linked paths—those files are the contract for what exists in-repo vs on-disk outside the clone.

## AI Agent Roles

The development and execution of Final Evolution Lab is coordinated across specialized AI agent profiles:

- **Antigravity**: Primary active executor and local builder/auditor. Responsible for Unreal Engine builds, iOS packaging, repository patches, Xcode configurations, device deployment, and final truth/readiness checks.
- **Seele AI**: Content and gameplay producer. Responsible for environment layouts, gameplay maps, spawn plans, interactables, and playable venue specifications.
- **Abacus AI**: System design source. Responsible for architecture blueprints, data schemas, and API contracts.
- **Emergent**: Legacy/historical scaffolding. Maintained for reference and legacy backend compatibility only, with active roles succeeded by local execution on Antigravity.

