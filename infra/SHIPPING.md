# Final Evolution Lab — iOS Shipping Guide

> **Goal:** Produce a signed `.ipa` for **iPhone 16 Pro Max** ready for TestFlight / App Store.
> The build runs on **macOS** (Linux preview environment cannot produce IPAs).

---

## 1. Pre-requisites (Mac side)

| Tool | Version | Notes |
|---|---|---|
| macOS | 14.5+ (Sonoma) | Required for Xcode 15.4 |
| Xcode | 15.4+ | `xcode-select --install` and accept license |
| UE5 | 5.7 source build | Installed at `/Users/Shared/Epic Games/UE_5.7` |
| Apple Developer account | Active | Capable of provisioning a Team ID |
| `iPhone 16 Pro Max` device or simulator | iOS 18+ | For on-device verification |

Verify:
```bash
xcodebuild -version          # ≥ 15.4
which RunUAT.sh              # /Users/Shared/Epic Games/UE_5.7/Engine/Build/BatchFiles/RunUAT.sh
echo "$TEAM_ID"              # 10-char Apple Developer Team ID
```

## 2. Pull repo

```bash
git clone <your-repo> ~/FinalEvolutionLab
cd ~/FinalEvolutionLab
chmod +x fel_ue5_ios_shipping_package.sh infra/fel_prebuild_ci_check.sh
```

## 3. Set required env vars

```bash
export TEAM_ID="ABCDE12345"
export BUNDLE_ID="com.finalevolution.lab"
export BACKEND_URL="https://api.finalevolutionlab.com"   # for handshake verify
# Optional overrides
export UE_ROOT="/Users/Shared/Epic Games/UE_5.7"
export UPROJECT="$PWD/FinalEvolutionLab.uproject"
export DEVICE="iPhone16,2"   # iPhone 16 Pro Max
```

## 4. Run the shipping pipeline

```bash
./fel_ue5_ios_shipping_package.sh --shipping
```

What this does (fail-fast, idempotent):
1. `infra/fel_prebuild_ci_check.sh` — UE5 descriptor / scheme integrity guard
2. `GET ${BACKEND_URL}/api/sovereign/handshake/verify` — confirms the iOS bridge can talk to the production Sovereign Hub
3. `RunUAT.sh BuildCookRun` for IOS Shipping (cook, build, stage, pak, archive)
4. `xcodebuild archive` → `.xcarchive`
5. `xcodebuild -exportArchive` with `infra/ue5_config/ExportOptions.plist` → `.ipa`
6. Writes `dist/ios/manifest.json` with build metadata
7. Logs land in `dist/ios/logs/{uat,archive,export}.log`

## 5. Upload to App Store Connect

```bash
xcrun altool --upload-app \
    -f dist/ios/FinalEvolutionLab.ipa \
    -t ios \
    -u "$APPLE_ID" \
    -p "$APP_SPECIFIC_PWD"
```

Or use **Transporter.app** (drag-and-drop the IPA).

## 6. iPhone 16 Pro Max — on-device verification

After TestFlight install:
1. Launch FEL → tap **FEL OS / Game Modes / Brain Brawl Arena**
2. Confirm deep link: `finalevolution://brain-brawl/launch` opens UE5 binary
3. Watch **Sovereign Hub**: the `/api/sovereign/status` should show `connected_clients: ["ios-..."]`
4. Verify telemetry frames flow on the dashboard (PRQ updates within 500 ms)

## 7. Sovereign Hub Handshake — what it checks

`GET /api/sovereign/handshake/verify` returns:

```json
{
  "ok": true,
  "version": "2.0.0",
  "expected_ws_url": "wss://finalevolutiongroup.com/ws/sovereign",
  "device_target": "iPhone16,2",
  "encryption": "AES-256-GCM",
  "focus_lock": true,
  "keepalive_interval_s": 0.5
}
```

If `ok` is `false`, the build is aborted before signing. Common causes:
- Mismatched `EMERGENT_GAME_WS_URL` in backend `.env`
- Production backend not deployed yet
- Encryption mode drift

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| `Code signing required` | Confirm `TEAM_ID` env var; `--allowProvisioningUpdates` is already set |
| `RunUAT: missing target` | Ensure `FinalEvolutionLab.Target.cs` is in `Source/` |
| `descriptor not found` | Run `infra/fix_ios_descriptor_path.sh` once; re-build |
| Handshake `ok: false` | Check backend `.env` `EMERGENT_GAME_WS_URL` matches `wss://finalevolutiongroup.com/ws/sovereign` |
| IPA size > 500 MB | Disable unused UE5 plugins; check `--nodebuginfo` is set |

---

**You are not packaging a binary — you are licensing an athlete-sovereign OS to the App Store.**
Don't ship until the handshake is green and a real iPhone 16 Pro Max passes the on-device boot.
