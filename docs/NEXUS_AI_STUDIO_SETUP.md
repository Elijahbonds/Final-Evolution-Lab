# NEXUS — Google AI Studio setup

**Canonical repo:** `/Users/elijahbonds/Final-Evolution-Lab`  
**Migration context:** Firebase is **optional** for distribution/analytics. **Google AI Studio** (Gemini REST) is the **primary AI backend** for game generation, agent chat, and NEXUS Studio — no `GoogleService-Info.plist` required.

## What AI Studio replaces vs what Firebase still does

| Capability | Primary backend | Firebase required? |
|------------|-----------------|------------------|
| Game generator (`fel.generate.game`) | AI Studio / Gemini REST | **No** |
| Agent tool planner (`NEXUSAgentLLMClient`) | AI Studio / Gemini REST | **No** |
| NEXUS Studio AI settings + Run panel | AI Studio / Keychain | **No** |
| Template-only fallback (18 modes) | Local heuristics | **No** |
| Crashlytics symbol upload | Firebase Crashlytics | Optional |
| Anonymous Auth / Firestore sync | Firebase | Optional |
| App Distribution (ad-hoc IPA sideload) | Firebase Console | Optional |
| TestFlight / App Store | App Store Connect | No Firebase for IPA export |

Honest labeling: without an API key the app uses **template MVP** (`adapter: template_mvp`). With a key and successful REST call: **`ai_provider: ai_studio`** / `gemini_assisted`.

---

## 1. Get an API key from Google AI Studio

1. Open **Google AI Studio**: https://aistudio.google.com/apikey  
2. Sign in with your Google account (same org as Gemini billing if applicable).  
3. Click **Create API key** → choose or create a Google Cloud project.  
4. Copy the key once — treat it like a password. **Do not commit it to git.**

Rate limits and billing follow Google AI Studio / Cloud project policy. Default model in NEXUS: `gemini-2.0-flash` (override via env — see below).

---

## 2. Configure the key (pick one or more surfaces)

### iOS app — Xcode scheme (dev)

1. Xcode → **FinalEvolutionLab** scheme → **Edit Scheme…** → **Run** → **Arguments** → **Environment Variables**  
2. Add:

| Variable | Example | Notes |
|----------|---------|-------|
| `NEXUS_AI_STUDIO_API_KEY` | `AIza…` | **Preferred** name |
| `NEXUS_AI_STUDIO_MODEL` | `gemini-2.0-flash` | Optional |
| `NEXUS_AGENT_GEMINI_KEY` | `AIza…` | Legacy alias (still supported) |
| `GEMINI_API_KEY` | `AIza…` | Legacy alias |

3. Run the app. Dashboard / Studio should show **AI STUDIO · CONNECTED** (never displays the key).

### iOS app — Keychain (device / TestFlight without scheme env)

`NexusAIStudioBootstrap` persists keys securely:

- **Service:** `com.finalevolutionlab.nexus.aistudio`  
- **Account:** `gemini_api_key`  
- **Resolution order:** env vars → Keychain  

Store via **NEXUS Studio → AI Studio settings** (API key field + connection test), or programmatically:

```swift
NexusAIStudioBootstrap.storeAPIKeyInKeychain("AIza…")
```

On first launch with a scheme env key, the bootstrap may copy the key into Keychain so later launches work without Xcode env vars.

Clear Keychain key:

```swift
NexusAIStudioBootstrap.clearKeychainAPIKey()
```

### Headless engine / CI / Cursor shell

```bash
export NEXUS_AI_STUDIO_API_KEY="AIza…"
# or legacy:
export NEXUS_AGENT_GEMINI_KEY="AIza…"

./scripts/nexus_build_gate.sh
./build-headless/nexus_gameplay_test   # optional live Gemini tests
```

C++ resolution: `nexus::ai::NexusAIStudioConfig::resolve()` in `engine/ai_interface/src/nexus_ai_studio_config.cpp`.

Env precedence (highest wins):

1. `NEXUS_AI_STUDIO_API_KEY`, `NEXUS_AGENT_GEMINI_KEY`, `GEMINI_API_KEY`, `FEL_LLM_KEY`  
2. Keychain (iOS only)  
3. Exported AI Studio JSON in `~/Downloads` (see §3)  
4. `.env` / `.env.local` in Downloads with `GEMINI_API_KEY=…`

### Optional: AI Studio exported config JSON

If AI Studio exports a JSON config to Downloads:

```bash
export NEXUS_AI_STUDIO_CONFIG_PATH="$HOME/Downloads/my-aistudio-config.json"
```

The engine parses `apiKey`, `apiKeyEnvVar`, `model`, and `baseUrl` fields and resolves `${ENV_VAR}` references without writing secrets into the repo.

---

## 3. Verify AI Studio (no Firebase)

### iOS

1. Ensure **no** real Firebase plist is required: app boots with `NexusAIStudioBootstrap.configureIfNeeded()` at launch.  
2. Open **Dashboard** — status card should read `AI STUDIO · CONNECTED · gemini-2.0-flash · Env` or `Keychain`.  
3. **Arena → Create** — generate a game; metadata should show `ai_provider: ai_studio` when live (or `template_mvp` when offline).  
4. **NEXUS Studio → AI Studio** — run connection test (“ping Gemini”).

### Headless

```bash
export NEXUS_AI_STUDIO_API_KEY="…"
cmake --build build-headless --target nexus_gameplay_test
./build-headless/nexus_gameplay_test
```

### Template-only (App Store / offline QA)

Omit all API keys. Generator and agent chat remain usable via 18-mode template heuristics — no network, no Firebase.

---

## 4. Abacus download → NEXUS asset pipeline (Phase 2 cross-ref)

Abacus AI provides **architecture blueprints and contracts** (mode registry, PRQ, venue semantics) — not mesh binaries. Mesh drops from Abacus-adjacent exports (Luma, Meshy, Seele FBX/GLB) ingest through the same NEXUS pipeline.

**When new files appear in `~/Downloads/`** (Abacus export sessions, Luma scans, Meshy GLB, etc.):

| Step | Action |
|------|--------|
| 1 | **Catalog** recent drops (last 30 days): `*abacus*`, `*luma*`, `*meshy*`, `*nexus*`, `*.glb`, `*.fbx`, `*.plist` (Firebase plist is **not** AI Studio — keep separate) |
| 2 | **Cross-reference** `assets/nexus/imported/`, `assets/nexus/manifests/nexus_asset_manifest.json`, `assets/nexus/NEXUS_CONTENT_GAPS.md`, `seeles_work/` |
| 3 | **Stage source** (gitignored): `cp ~/Downloads/MyVenue.glb assets/nexus/source/` |
| 4 | **Import + mobile LOD** | See commands below |
| 5 | **Gate** | `NEXUS_MESH_PROFILE=mobile ./scripts/nexus_validate_production_modes.sh` |
| 6 | **Document** | Update `assets/nexus/NEXUS_CONTENT_GAPS.md` with new asset_id / mode mapping |

**Import commands:**

```bash
cd /Users/elijahbonds/Final-Evolution-Lab

# From manifest asset id (FBX already in source/ or CDN):
python3 scripts/nexus_import_assets.py --convert --update-manifest --mobile --asset venice_beach_court_model_fbx

# From a fresh GLB drop:
python3 scripts/nexus_import_assets.py \
  --from-gltf assets/nexus/source/my_venue.glb \
  --mobile --convert --update-manifest \
  --output assets/nexus/imported/my_venue_mobile.nexusmesh.json
```

Abacus blueprint docs live under `docs/design_reference/` and `seeles_work/` — align venue/mode names there before editing the manifest. Repo marker: `.abacus.donotdelete` (do not delete; Abacus Desktop sync anchor).

Full pipeline: `docs/architecture/NEXUS_Asset_Pipeline.md`.

---

## 5. Ship path summary (AI Studio + optional Firebase)

### Daily dev (AI only)

```bash
./scripts/build-nexus-ios.sh
# Set NEXUS_AI_STUDIO_API_KEY in Xcode scheme or Keychain
# Run FinalEvolutionLab on Simulator or device — Firebase optional
```

### Internal QA IPA (no Firebase plist)

```bash
./scripts/archive-ios-testflight.sh --preview-firebase --export-adhoc
# Upload build/FEL-Firebase-Distribution.ipa → Firebase App Distribution
```

See `infra/FIREBASE_APP_DISTRIBUTION.md` and `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt`.

### TestFlight (ASC app record)

```bash
./scripts/archive-ios-testflight.sh --preview-firebase --export
# Transporter → build/FEL-export/FinalEvolutionLab.ipa
```

### Production Firebase lane (optional Crashlytics + Auth)

Real `GoogleService-Info.plist` + `./scripts/archive-ios-testflight.sh --export` — see Firebase checklist.

---

## 6. Disk space for archive / export

**Require ≥ 15 GB free** on the internal data volume before Release archive or export.

Archive writes `build/FEL.xcarchive`, `build/DerivedData-archive/`, and export IPAs (~80–100 MB each). Concurrent `xcodebuild` + archive on a full disk causes `build.db` I/O failures.

```bash
df -g / | awk 'NR==2 {print "Free GB:", $4}'
# Need ≥ 15 before:
./scripts/archive-ios-testflight.sh --preview-firebase --export-adhoc
```

Recovery: `rm -rf build/DerivedData-archive` then re-run, or use `--export-only` from an existing `build/FEL.xcarchive`.

---

## Related files

| File | Role |
|------|------|
| `FinalEvolutionLab/Services/NexusAIStudioBootstrap.swift` | iOS key resolution + Keychain |
| `engine/ai_interface/include/nexus/ai/nexus_ai_studio_config.h` | C++ AI Studio config |
| `engine/ai_interface/src/nexus_ai_studio_config.cpp` | Env + Downloads JSON resolution |
| `docs/NEXUS_GAME_GENERATOR.md` | Generator tiers + metadata |
| `docs/NEXUS_AGENT_TOOLS.md` | Agent Gemini backend |
| `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt` | Firebase optional lanes + AI Studio checklist |
| `infra/FIREBASE_APP_DISTRIBUTION.md` | Distribution (Firebase optional) |
