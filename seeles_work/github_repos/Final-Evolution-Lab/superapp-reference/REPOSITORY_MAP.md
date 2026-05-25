# Repository map (whole-app orientation)

Paths are relative to repo root. Depth is intentional—open these folders, don’t assume “only frontend” or “only Unreal.”

| Path | Role |
|------|------|
| `UnrealIntegration/` | Drop-in **C++ modules + Config snippets** for the live UE project |
| `UnrealStarter/BasketballGame/` | **UE project mirror**: Content, Config, packaging snippets |
| `FinalEvolutionLab/` | **Swift/Xcode shell** — SwiftUI, HealthKit services, native UX experiments |
| `FinalEvolutionLab.xcodeproj/` | Xcode project for Swift shell (distinct from UE-generated `(IOS).xcworkspace` on disk) |
| `backend/` | **Python FastAPI** — APIs, routers, vault/session concepts |
| `frontend/` | **React** — dashboards and labs used for web parity / WKWebView targets |
| `infra/` | **UE plist/export configs**, automation helpers (`infra/ue5_config/`) |
| `Config/` | Repo-level iOS **capability checklist** text files |
| `fel_ue5_ios_shipping_package.sh` | **Primary macOS script** for UE iOS Shipping pipeline |
| `prepare_fel_full_ship.sh` | Merges full-ship **DefaultGame.ini** sections |
| `artifacts/` | Local **build outputs / archives** (often gitignored partially—may be empty in clone) |
| `docs/` | Miscellaneous docs |
| `memory/` | PRD / narrative memory (human-oriented) |
| `scripts/` | Helper scripts (avoid resurrecting removed distribution generators) |
| `tests/` / `test_reports/` | Automated test artifacts |

**Outside this repo (typical):** `~/Developer/FinalEvolutionLab57/` — canonical **UE project + Generated Xcode `(IOS).xcworkspace`** on your Mac. Superapp/build automation must either run **on that Mac** or consume **exported IPA + metadata** produced there.
