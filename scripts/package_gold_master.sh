#!/usr/bin/env bash
# Universal Master — Final Deployment Script (single entry): Luma texture stamps, Xcode archives, MANIFEST, report.
#
# Environment:
#   FEL_UNIVERSAL_STAMP_PLATFORMS="ios mac ps5 android" — run fel_luma_venue_texture_presave.py per platform (ASTC=iOS, BC7=Mac/PS5, ETC2=Android).
#   FEL_SKIP_STAMP=1 — skip all Editor Python stamp steps.
#   UNREAL_EDITOR / UNREAL_ENGINE_ROOT — UnrealEditor binary
#   FEL_UNREAL_UPROJECT — path to .uproject
#   FEL_XCODE_SCHEME / FEL_IOS_CONFIGURATION / FEL_MAC_CONFIGURATION — default Release (use Development + Ad-Hoc export plist for device iter).
#   FEL_EXPORT_OPTIONS_PLIST — iOS -exportArchive (Ad-Hoc or Development per your provisioning).
#   FEL_BUILD_MAC=0 — skip macOS archive
#   UNREAL_ENGINE_ROOT + FEL_UNREAL_UPROJECT — optional RunUAT BuildCookRun (Shipping)
#   FEL_MANIFEST_PATH — default $ROOT/build/MANIFEST.txt
#   FEL_DEVICE_SMOKE_TEST=1 — after iOS archive, install .app to first connected device via `xcrun devicectl` and launch (bundle: FEL_SMOKE_BUNDLE_ID, default com.finalevolution.FinalEvoAPP).
#   FEL_BUILD_MAC=1 — also `open` the macOS .app from the mac archive when smoke test is on (verifies local Handshake / Coach paths on Mac).
#   TestFlight (Pillar 1): FEL_SKIP_TESTFLIGHT_UPLOAD=1 skips upload. Prefer App Store Connect API key:
#     FEL_APPSTORE_CONNECT_API_KEY_ID, FEL_APPSTORE_CONNECT_API_ISSUER_ID, optional FEL_APPSTORE_CONNECT_API_KEY_PATH (.p8).
#     Pre-flight: if those two are unset, the script prints an ACTION REQUIRED block before upload (legacy Apple ID path may still run).
#     Or legacy: FEL_APPLE_ID + FEL_APP_SPECIFIC_PASSWORD. Target bundle: FEL_TESTFLIGHT_BUNDLE_ID (default com.finalevolution.FinalEvoAPP) — verify in App Store Connect matches IPA.
#   FEL_SKIP_SIGNING_VERIFY=1 — skip provisioning-profile pre-check (CI hosts without Apple login / profiles).
#   FEL_TESTFLIGHT_LOG — default $ROOT/LOGS/testflight_upload.log (altool stdout/stderr tee for forensic review).
#
# PS5: texture stamp uses BC7 via Python on this Mac host; console packages are produced on Windows/PS5 SDK — see build report note.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FEL_SOVEREIGN_GREP_ALLOWLIST="${FEL_SOVEREIGN_GREP_ALLOWLIST:-Sovereign sovereign Luma_Venice Luma}"

# --- Host platform (orchestrator always runs where Xcode is available; PS5 cook is documented separately) ---
HOST_OS="$(uname -s)"
echo "==> Final Evolution Lab — Universal Master orchestrator"
echo "    ROOT=$ROOT"
echo "    HOST_OS=$HOST_OS"

UNREAL_IOS_OUT="${FEL_UNREAL_IOS_OUT:-$ROOT/build/Unreal/IOS}"
mkdir -p "$UNREAL_IOS_OUT"

PROJECT="$ROOT/FinalEvolutionLabUnreal.xcodeproj"
SCHEME="${FEL_XCODE_SCHEME:-FinalEvolutionLabUnreal}"
CONFIGURATION_IOS="${FEL_IOS_CONFIGURATION:-${FEL_XCODE_CONFIGURATION:-Release}}"
CONFIGURATION_MAC="${FEL_MAC_CONFIGURATION:-${FEL_XCODE_CONFIGURATION:-Release}}"
ARCHIVE_PATH="${FEL_ARCHIVE_PATH:-$ROOT/build/FinalEvolutionLabUnreal.xcarchive}"
MAC_ARCHIVE_PATH="${FEL_MAC_ARCHIVE_PATH:-$ROOT/build/FinalEvolutionLabUnreal.mac.xcarchive}"
EXPORT_PATH="${FEL_EXPORT_PATH:-$ROOT/build/ipa_export}"
EXPORT_OPTIONS="${FEL_EXPORT_OPTIONS_PLIST:-$ROOT/scripts/DevelopmentExportOptions.plist}"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-$HOME/Library/Developer/Xcode/DerivedData}"
FEL_BUILD_MAC="${FEL_BUILD_MAC:-1}"
FEL_MANIFEST_PATH="${FEL_MANIFEST_PATH:-$ROOT/build/MANIFEST.txt}"

REPORT_TXT="${FEL_BUILD_REPORT_PATH:-$ROOT/build/GOLD_MASTER_BUILD_REPORT.txt}"
STAMP_STATUS="SKIPPED"
STAMP_DETAIL="(UNREAL_EDITOR or FEL_UNREAL_UPROJECT not set)"
MAC_STATUS="SKIPPED"
MAC_DETAIL=""
IOS_ARCHIVE_STATUS="PENDING"
IPA_STATUS="PENDING"
SOVEREIGN_IPA="UNKNOWN"
SOVEREIGN_MAC="UNKNOWN"
MANIFEST_STATUS="SKIPPED"
FEL_CFG_DEFAULT_GAME="${ROOT}/UnrealStarter/BasketballGame/CONFIG_DefaultGame_FEL.ini"
if [[ -f "$FEL_CFG_DEFAULT_GAME" ]] && grep -q 'FEL_VERIFY_SOVEREIGN_GEAR_TEXTURE_PX_PS5_PRO=4096' "$FEL_CFG_DEFAULT_GAME" && grep -q 'FEL_VERIFY_SOVEREIGN_GEAR_TEXTURE_PX_IOS_ASTC=1024' "$FEL_CFG_DEFAULT_GAME"; then
	SOVEREIGN_GEAR_TEX_VERIFY="PASS (CONFIG_DefaultGame_FEL.ini declares PS5 Pro 4096 + iOS ASTC 1024)"
else
	SOVEREIGN_GEAR_TEX_VERIFY="WARN (add FEL_VERIFY_SOVEREIGN_GEAR_TEXTURE_* tokens to CONFIG_DefaultGame_FEL.ini)"
fi

# --- Pillar 1: Luma venue texture stamp — ASTC (iOS), BC7 (Mac/PS5) via Editor Python ---
STAMP_SCRIPT="${FEL_STAMP_SCRIPT:-$ROOT/UnrealStarter/BasketballGame/EditorPython/fel_luma_venue_texture_presave.py}"
UNREAL_BIN="${UNREAL_EDITOR:-}"
if [[ -z "$UNREAL_BIN" && -n "${UNREAL_ENGINE_ROOT:-}" ]]; then
	UNREAL_BIN="$UNREAL_ENGINE_ROOT/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor"
fi

if [[ "${FEL_SKIP_STAMP:-0}" != "1" && -x "$UNREAL_BIN" && -n "${FEL_UNREAL_UPROJECT:-}" && -f "${FEL_UNREAL_UPROJECT}" && -f "$STAMP_SCRIPT" ]]; then
	mkdir -p "$ROOT/build"
	: >"$ROOT/build/fel_luma_stamp_log.txt"
	STAMP_PLATFORMS="${FEL_UNIVERSAL_STAMP_PLATFORMS:-ios mac ps5 android}"
	STAMP_OK=1
	for P in $STAMP_PLATFORMS; do
		echo "==> [Universal Master] fel_luma_venue_texture_presave.py — FEL_STAMP_PLATFORM=$P (ASTC=ios / BC7=mac|ps5)"
		export FEL_STAMP_PLATFORM="$P"
		export FEL_RUN_STAMP=1
		set +o pipefail
		if "$UNREAL_BIN" "$FEL_UNREAL_UPROJECT" -unattended -nop4 -nosplash -run=pythonscript -script="$STAMP_SCRIPT" 2>&1 | tee -a "$ROOT/build/fel_luma_stamp_log.txt"; then
			:
		else
			STAMP_OK=0
		fi
		set -o pipefail
	done
	if [[ "$STAMP_OK" -eq 1 ]]; then
		STAMP_STATUS="OK"
		STAMP_DETAIL="platforms=$STAMP_PLATFORMS (see build/fel_luma_stamp_log.txt)"
	else
		STAMP_STATUS="WARN"
		STAMP_DETAIL="one or more stamp invocations failed — see build/fel_luma_stamp_log.txt"
	fi
else
	echo "WARN: [Stamp] Skipping Luma texture presave — set UNREAL_EDITOR (or UNREAL_ENGINE_ROOT), FEL_UNREAL_UPROJECT, or FEL_SKIP_STAMP=1"
fi

# --- Optional: Unreal UAT Shipping ---
if [[ -n "${UNREAL_ENGINE_ROOT:-}" && -n "${FEL_UNREAL_UPROJECT:-}" ]]; then
	UAT="$UNREAL_ENGINE_ROOT/Engine/Build/BatchFiles/RunUAT.sh"
	if [[ -x "$UAT" ]]; then
		echo "==> Unreal BuildCookRun (Shipping)"
		"$UAT" BuildCookRun \
			-project="$FEL_UNREAL_UPROJECT" \
			-noP4 \
			-clientconfig=Shipping \
			-cook \
			-allmaps \
			-stage \
			-package \
			-build \
			-archive \
			${FEL_UAT_EXTRA_ARGS:-} || true
	fi
fi

# --- DerivedData prune ---
if [[ "${FEL_DERIVED_DATA_CLEAN_ALL:-0}" == "1" ]]; then
	echo "==> Removing entire DerivedData: $DERIVED_DATA_ROOT"
	rm -rf "$DERIVED_DATA_ROOT"
else
	echo "==> Pruning DerivedData entries matching FinalEvolutionLab*"
	find "$DERIVED_DATA_ROOT" -maxdepth 1 -type d -name 'FinalEvolutionLab*' -exec rm -rf {} + 2>/dev/null || true
fi

# --- Build number bump ---
PBX="$PROJECT/project.pbxproj"
if [[ ! -f "$PBX" ]]; then
	echo "ERROR: Missing $PBX"
	exit 1
fi
CURRENT="$(grep -E '^\s*CURRENT_PROJECT_VERSION = [0-9]+;' "$PBX" | head -1 | sed -E 's/.*= ([0-9]+);/\1/')"
if [[ -z "${CURRENT:-}" ]]; then
	echo "WARN: Could not read CURRENT_PROJECT_VERSION; skipping bump."
else
	NEXT=$((CURRENT + 1))
	echo "==> Build version: $CURRENT -> $NEXT"
	if [[ "$(uname)" == "Darwin" ]]; then
		sed -i '' -E "s/(CURRENT_PROJECT_VERSION = )[0-9]+;/\1${NEXT};/g" "$PBX"
	else
		sed -i -E "s/(CURRENT_PROJECT_VERSION = )[0-9]+;/\1${NEXT};/g" "$PBX"
	fi
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")"
mkdir -p "$(dirname "$MAC_ARCHIVE_PATH")"
mkdir -p "$EXPORT_PATH"
mkdir -p "$ROOT/build"
mkdir -p "$ROOT/LOGS"

FEL_TESTFLIGHT_LOG="${FEL_TESTFLIGHT_LOG:-$ROOT/LOGS/testflight_upload.log}"

# --- Zero-Failure: signing / provisioning pre-check (before long iOS archive) ---
FEL_TF_BUNDLE_SIGN="${FEL_TESTFLIGHT_BUNDLE_ID:-com.finalevolution.FinalEvoAPP}"
if [[ "${FEL_SKIP_SIGNING_VERIFY:-0}" != "1" && "$HOST_OS" == "Darwin" ]]; then
	echo "==> Pre-Flight: iOS signing — provisioning profile for ${FEL_TF_BUNDLE_SIGN}"
	export FEL_SIGNING_BUNDLE_ID="$FEL_TF_BUNDLE_SIGN"
	if ! command -v python3 >/dev/null 2>&1; then
		echo "ERROR: python3 is required for provisioning profile verification (or set FEL_SKIP_SIGNING_VERIFY=1)."
		exit 1
	fi
	if python3 <<'FEL_SIGN_PY'
import os, plistlib, subprocess, glob, sys
from datetime import datetime, timezone

bundle = os.environ.get("FEL_SIGNING_BUNDLE_ID", "com.finalevolution.FinalEvoAPP")
dirs = [
    os.path.expanduser("~/Library/Developer/Xcode/UserData/Provisioning Profiles"),
    os.path.expanduser("~/Library/MobileDevice/Provisioning Profiles"),
]
now = datetime.now(timezone.utc)
for d in dirs:
    if not os.path.isdir(d):
        continue
    for path in glob.glob(os.path.join(d, "*.mobileprovision")):
        try:
            out = subprocess.check_output(["security", "cms", "-D", "-i", path], stderr=subprocess.DEVNULL)
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue
        try:
            pl = plistlib.loads(out)
        except Exception:
            continue
        ent = pl.get("Entitlements") or {}
        aid = ent.get("application-identifier") or ""
        if not aid.endswith(bundle):
            continue
        exp = pl.get("ExpirationDate")
        if exp is None:
            continue
        if isinstance(exp, datetime):
            if exp.tzinfo is None:
                exp = exp.replace(tzinfo=timezone.utc)
            if exp > now:
                print("OK", path)
                sys.exit(0)
sys.exit(1)
FEL_SIGN_PY
	then
		echo "    PASS: Found non-expired provisioning profile matching application-identifier *.${FEL_TF_BUNDLE_SIGN}"
	else
		echo "ERROR: No valid (non-expired) provisioning profile for '${FEL_TF_BUNDLE_SIGN}'."
		echo "       Install a profile in Xcode (Signing & Capabilities) or set FEL_SKIP_SIGNING_VERIFY=1 to bypass on CI."
		exit 1
	fi
elif [[ "${FEL_SKIP_SIGNING_VERIFY:-0}" == "1" ]]; then
	echo "WARN: FEL_SKIP_SIGNING_VERIFY=1 — skipping provisioning profile pre-check"
fi

# --- Pillar 2: xcodebuild iOS archive (iphoneos) + export (Ad-Hoc / Development per export plist) ---
echo "==> [Universal Master] xcodebuild archive iOS (scheme=$SCHEME configuration=$CONFIGURATION_IOS)"
echo "    Use FEL_EXPORT_OPTIONS_PLIST with method=ad-hoc or development for device distribution."
if xcodebuild \
	-project "$PROJECT" \
	-scheme "$SCHEME" \
	-configuration "$CONFIGURATION_IOS" \
	-sdk iphoneos \
	-archivePath "$ARCHIVE_PATH" \
	-destination 'generic/platform=iOS' \
	-allowProvisioningUpdates \
	archive \
	CODE_SIGN_STYLE=Automatic \
	${FEL_XCODEBUILD_ARGS:-}; then
	IOS_ARCHIVE_STATUS="OK"
else
	IOS_ARCHIVE_STATUS="FAIL"
	echo "ERROR: iOS archive failed"
	exit 1
fi

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
	echo "ERROR: Missing export options plist: $EXPORT_OPTIONS"
	exit 1
fi

echo "==> xcodebuild -exportArchive (plist=$EXPORT_OPTIONS) -> $EXPORT_PATH"
if xcodebuild \
	-exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportPath "$EXPORT_PATH" \
	-exportOptionsPlist "$EXPORT_OPTIONS" \
	-allowProvisioningUpdates \
	${FEL_XCODEBUILD_EXPORT_ARGS:-}; then
	IPA_STATUS="OK"
else
	IPA_STATUS="FAIL"
fi

IPA_FILE="$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print 2>/dev/null | head -1 || true)"
if [[ -n "${IPA_FILE:-}" && -f "$IPA_FILE" ]]; then
	IPA_ABS="$(cd "$(dirname "$IPA_FILE")" && pwd)/$(basename "$IPA_FILE")"
	echo "==> IPA: $IPA_ABS"
	if unzip -l "$IPA_ABS" 2>/dev/null | grep -Eiq "Sovereign|Luma_Venice|Luma"; then
		SOVEREIGN_IPA="PASS (matched Sovereign/Luma path in .ipa listing)"
	else
		SOVEREIGN_IPA="WARN (no Sovereign/Luma string in zip listing — verify cooked content)"
	fi
else
	SOVEREIGN_IPA="N/A (no .ipa)"
fi

# --- TestFlight upload (App Store Connect / altool) ---
TESTFLIGHT_UPLOAD_STATUS="SKIPPED (set API credentials or FEL_SKIP_TESTFLIGHT_UPLOAD=1)"
FEL_TF_BUNDLE="${FEL_TESTFLIGHT_BUNDLE_ID:-com.finalevolution.FinalEvoAPP}"
if [[ "${FEL_SKIP_TESTFLIGHT_UPLOAD:-0}" != "1" && -n "${IPA_ABS:-}" && -f "${IPA_ABS}" ]]; then
	echo "==> Pre-Flight: App Store Connect credential check (API key path)"
	if [[ -z "${FEL_APPSTORE_CONNECT_API_KEY_ID:-}" || -z "${FEL_APPSTORE_CONNECT_API_ISSUER_ID:-}" ]]; then
		cat <<'FEL_ASC_ACTION'

╔══════════════════════════════════════════════════════════════════════════════╗
║ ACTION REQUIRED — App Store Connect API (final TestFlight push)             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ The recommended upload path needs BOTH of these environment variables set   ║
║ in the same shell session (or CI secrets) before running this script:       ║
║                                                                              ║
║   export FEL_APPSTORE_CONNECT_API_KEY_ID="<Key ID from App Store Connect>"  ║
║   export FEL_APPSTORE_CONNECT_API_ISSUER_ID="<Issuer ID — Users and Access>"  ║
║                                                                              ║
║ Optional (if the .p8 is not in the default search path):                     ║
║   export FEL_APPSTORE_CONNECT_API_KEY_PATH="$HOME/AuthKey_XXXXXXXXXX.p8"      ║
║                                                                              ║
║ Create keys: App Store Connect → Users and Access → Keys → App Store        ║
║ Connect API. Download the .p8 once; store it securely (never commit).       ║
║                                                                              ║
║ If you use Apple ID + app-specific password instead, set:                    ║
║   FEL_APPLE_ID  and  FEL_APP_SPECIFIC_PASSWORD                               ║
╚══════════════════════════════════════════════════════════════════════════════╝

FEL_ASC_ACTION
	else
		echo "    Pre-Flight OK: FEL_APPSTORE_CONNECT_API_KEY_ID and FEL_APPSTORE_CONNECT_API_ISSUER_ID are set."
	fi
	echo "==> TestFlight upload (bundle id reference: $FEL_TF_BUNDLE)"
	echo "    Forensic log: $FEL_TESTFLIGHT_LOG"
	mkdir -p "$(dirname "$FEL_TESTFLIGHT_LOG")"
	: >>"$FEL_TESTFLIGHT_LOG"
	set +e
	set +o pipefail
	if [[ -n "${FEL_APPSTORE_CONNECT_API_KEY_ID:-}" && -n "${FEL_APPSTORE_CONNECT_API_ISSUER_ID:-}" ]]; then
		ALT=(xcrun altool --upload-app --file "$IPA_ABS" --type ios --apiKey "$FEL_APPSTORE_CONNECT_API_KEY_ID" --apiIssuer "$FEL_APPSTORE_CONNECT_API_ISSUER_ID")
		if [[ -n "${FEL_APPSTORE_CONNECT_API_KEY_PATH:-}" && -f "${FEL_APPSTORE_CONNECT_API_KEY_PATH}" ]]; then
			ALT+=(--api-key-file "$FEL_APPSTORE_CONNECT_API_KEY_PATH")
		fi
		{
			echo ""
			echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) altool --upload-app (App Store Connect API) ==="
		} >>"$FEL_TESTFLIGHT_LOG"
		"${ALT[@]}" 2>&1 | tee -a "$FEL_TESTFLIGHT_LOG"
		TF_EXIT=${PIPESTATUS[0]}
	elif [[ -n "${FEL_APPLE_ID:-}" && -n "${FEL_APP_SPECIFIC_PASSWORD:-}" ]]; then
		{
			echo ""
			echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) altool --upload-app (Apple ID) ==="
		} >>"$FEL_TESTFLIGHT_LOG"
		xcrun altool --upload-app --file "$IPA_ABS" --type ios --username "$FEL_APPLE_ID" --password "$FEL_APP_SPECIFIC_PASSWORD" 2>&1 | tee -a "$FEL_TESTFLIGHT_LOG"
		TF_EXIT=${PIPESTATUS[0]}
	else
		echo "WARN: TestFlight upload skipped — export FEL_APPSTORE_CONNECT_API_KEY_ID + FEL_APPSTORE_CONNECT_API_ISSUER_ID (and optional FEL_APPSTORE_CONNECT_API_KEY_PATH), or FEL_APPLE_ID + FEL_APP_SPECIFIC_PASSWORD."
		TF_EXIT=2
	fi
	set -o pipefail
	set -e
	if [[ "$TF_EXIT" -eq 0 ]]; then
		TESTFLIGHT_UPLOAD_STATUS="OK (altool upload — verify processing in App Store Connect → TestFlight)"
	elif [[ "$TF_EXIT" -eq 2 ]]; then
		TESTFLIGHT_UPLOAD_STATUS="SKIPPED (no credentials)"
	else
		TESTFLIGHT_UPLOAD_STATUS="FAIL (altool exit $TF_EXIT — use Transporter.app or notarytool-era workflows if altool is deprecated on your Xcode)"
		echo "ERROR: TestFlight upload failed (exit $TF_EXIT)."
		exit 1
	fi
elif [[ "${FEL_SKIP_TESTFLIGHT_UPLOAD:-0}" == "1" ]]; then
	TESTFLIGHT_UPLOAD_STATUS="SKIPPED (FEL_SKIP_TESTFLIGHT_UPLOAD=1)"
fi

# --- Pillar 2b: macOS archive (Release) ---
if [[ "$FEL_BUILD_MAC" == "1" ]]; then
	echo "==> [Universal Master] xcodebuild archive macOS (configuration=$CONFIGURATION_MAC) -> $MAC_ARCHIVE_PATH"
	set +e
	xcodebuild \
		-project "$PROJECT" \
		-scheme "$SCHEME" \
		-configuration "$CONFIGURATION_MAC" \
		-sdk macosx \
		-archivePath "$MAC_ARCHIVE_PATH" \
		-destination 'generic/platform=macOS' \
		-allowProvisioningUpdates \
		archive \
		CODE_SIGN_STYLE=Automatic \
		${FEL_XCODEBUILD_MAC_ARGS:-}
	MAC_XCODE=$?
	set -e
	if [[ "$MAC_XCODE" -eq 0 ]]; then
		MAC_STATUS="OK"
		MAC_APP="$(find "$MAC_ARCHIVE_PATH" -name '*.app' -maxdepth 4 -print 2>/dev/null | head -1 || true)"
		if [[ -n "${MAC_APP:-}" ]]; then
			if find "$MAC_APP" -type f 2>/dev/null | head -c 50000000 | strings 2>/dev/null | grep -Eiq "Sovereign|Luma_Venice|Luma"; then
				SOVEREIGN_MAC="PASS (matched Sovereign/Luma in app bundle strings sample)"
			else
				SOVEREIGN_MAC="WARN (no Sovereign/Luma in sampled strings — verify Resources)"
			fi
			MAC_DETAIL="$MAC_APP"
		else
			SOVEREIGN_MAC="UNKNOWN (no .app in archive)"
		fi
	else
		MAC_STATUS="FAIL"
		MAC_DETAIL="(exit $MAC_XCODE — scheme may be iOS-only; set FEL_BUILD_MAC=0 to skip)"
	fi
else
	MAC_STATUS="SKIPPED (FEL_BUILD_MAC=0)"
fi

# --- Pillar 3: MANIFEST — SHA-256 of every asset path containing Sovereign or Luma ---
mkdir -p "$(dirname "$FEL_MANIFEST_PATH")"
{
	echo "# FEL Universal Master MANIFEST $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "# SHA-256  path"
	if command -v shasum >/dev/null 2>&1; then
		find "$ROOT" -type f \( -ipath '*Sovereign*' -o -ipath '*Luma*' \) ! -path '*/.git/*' ! -path '*/.cursor/*' 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
			[[ -f "$f" ]] || continue
			shasum -a 256 "$f" 2>/dev/null | awk -v p="$f" '{print $1 "  " p}'
		done
	fi
} | tee "$FEL_MANIFEST_PATH"
MANIFEST_STATUS="OK"

echo "==> MANIFEST written: $FEL_MANIFEST_PATH"

# --- Pillar 4: Device / Mac smoke (Handshake + AI Coach path verification) ---
SMOKE_STATUS="SKIPPED (set FEL_DEVICE_SMOKE_TEST=1 to install+launch)"
SMOKE_MAC="SKIPPED"
if [[ "${FEL_DEVICE_SMOKE_TEST:-0}" == "1" ]]; then
	IOS_APP="$(find "$ARCHIVE_PATH" -name '*.app' -print 2>/dev/null | head -1 || true)"
	if [[ -n "$IOS_APP" && -d "$IOS_APP" ]] && command -v xcrun >/dev/null 2>&1; then
		FIRST_DEV="$(xcrun devicectl list devices 2>/dev/null | grep -Eo '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1 || true)"
		if [[ -n "$FIRST_DEV" ]]; then
			BUNDLE_SMOKE="${FEL_SMOKE_BUNDLE_ID:-com.finalevolution.FinalEvoAPP}"
			set +e
			xcrun devicectl device install app --device "$FIRST_DEV" "$IOS_APP" >/dev/null 2>&1
			INST=$?
			set -e
			if [[ "$INST" -eq 0 ]]; then
				set +e
				xcrun devicectl device process launch --device "$FIRST_DEV" "$BUNDLE_SMOKE" >/dev/null 2>&1
				LNCH=$?
				set -e
				if [[ "$LNCH" -eq 0 ]]; then
					SMOKE_STATUS="OK (devicectl install+launch $BUNDLE_SMOKE on $FIRST_DEV)"
				else
					SMOKE_STATUS="PARTIAL (installed; launch exit $LNCH — check bundle id / provisioning)"
				fi
			else
				SMOKE_STATUS="FAIL (devicectl install exit $INST)"
			fi
		else
			SMOKE_STATUS="SKIP (no connected device UUID from devicectl list)"
		fi
	else
		SMOKE_STATUS="SKIP (no .app in xcarchive or no xcrun)"
	fi
	if [[ "${FEL_BUILD_MAC:-1}" == "1" && -n "${MAC_ARCHIVE_PATH:-}" ]]; then
		MAC_APP="$(find "$MAC_ARCHIVE_PATH" -name '*.app' -print 2>/dev/null | head -1 || true)"
		if [[ -n "$MAC_APP" && -d "$MAC_APP" ]]; then
			set +e
			open "$MAC_APP" 2>/dev/null
			OP=$?
			set -e
			if [[ "$OP" -eq 0 ]]; then
				SMOKE_MAC="OK (open macOS app)"
			else
				SMOKE_MAC="WARN (open failed exit $OP)"
			fi
		fi
	fi
fi

# --- Build report ---
{
	echo "========== FEL UNIVERSAL MASTER BUILD REPORT =========="
	echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "Host: $HOST_OS"
	echo "[Stamp] Luma venue texture presave (multi-platform): $STAMP_STATUS $STAMP_DETAIL"
	echo "[iOS] xcodebuild archive: $IOS_ARCHIVE_STATUS — $ARCHIVE_PATH (configuration=$CONFIGURATION_IOS)"
	echo "[iOS] IPA export: $IPA_STATUS — $EXPORT_PATH"
	echo "[macOS] xcodebuild archive: $MAC_STATUS ${MAC_DETAIL:+$MAC_DETAIL} (configuration=$CONFIGURATION_MAC)"
	echo "[Sovereign / Luma] .ipa grep: $SOVEREIGN_IPA"
	echo "[Sovereign / Luma] Mac .app strings: $SOVEREIGN_MAC"
	echo "[MANIFEST] Sovereign+Luma asset hashes: $MANIFEST_STATUS — $FEL_MANIFEST_PATH"
	echo "[Sovereign gear textures] cook target spec: $SOVEREIGN_GEAR_TEX_VERIFY"
	echo "[Smoke test] iOS device: $SMOKE_STATUS"
	echo "[Smoke test] macOS app: $SMOKE_MAC"
	echo "[TestFlight] altool upload: $TESTFLIGHT_UPLOAD_STATUS (bundle ref $FEL_TF_BUNDLE)"
	echo "Allowlist hint: $FEL_SOVEREIGN_GREP_ALLOWLIST"
	echo "[PS5] Console package not produced on Darwin — use Windows + PS5 SDK + UAT with PS5 target; BC7 stamp above aligns cooked textures."
	echo "[RC broadcast polish] FEL_BROADCAST_SONIC_FLARE_GLOBAL_TIME_DILATION=0.5 FEL_BROADCAST_SONIC_FLARE_HANG_SECONDS=0.2 FEL_BROADCAST_LUMA_VENICE_BLOOM_MULTIPLIER=2.0"
	echo "======================================================="
} | tee "$REPORT_TXT"

echo ""
echo "==> Build report written: $REPORT_TXT"
echo "==> Done."
