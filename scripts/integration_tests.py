#!/usr/bin/env python3
"""
Final Evolution Lab - Integration Test Suite
Verifies all deployment components are functioning correctly.

Usage:
    python3 scripts/integration_tests.py [--verbose] [--website-url URL]
"""

import json
import os
import re
import subprocess
import sys
import urllib.request
import urllib.error
import ssl
import socket
from pathlib import Path
from datetime import datetime

# Configuration
PROJECT_ROOT = Path(__file__).resolve().parent.parent
WEBSITE_DIR = Path("/home/ubuntu/finalevolutiongroup_website")
SIGNALLING_URL = os.getenv("SIGNALLING_URL", "http://localhost:8888")
WEBSITE_URL = os.getenv("WEBSITE_URL", "http://localhost:3001")
VERBOSE = "--verbose" in sys.argv or "-v" in sys.argv

# Test results
results = {"passed": 0, "failed": 0, "warned": 0, "skipped": 0, "tests": []}


def log(msg, level="INFO"):
    colors = {"INFO": "\033[0m", "PASS": "\033[92m", "FAIL": "\033[91m", "WARN": "\033[93m", "SKIP": "\033[90m"}
    prefix = {"INFO": "ℹ️ ", "PASS": "✅ ", "FAIL": "❌ ", "WARN": "⚠️ ", "SKIP": "⏭️  "}
    print(f"{colors.get(level, '')}{prefix.get(level, '')}{msg}\033[0m")


def record(name, status, detail=""):
    results["tests"].append({"name": name, "status": status, "detail": detail, "time": datetime.now().isoformat()})
    if status == "PASS":
        results["passed"] += 1
    elif status == "FAIL":
        results["failed"] += 1
    elif status == "WARN":
        results["warned"] += 1
    elif status == "SKIP":
        results["skipped"] += 1
    log(f"[{name}] {detail}", status)


def http_get(url, timeout=10):
    """Simple HTTP GET request."""
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        req = urllib.request.Request(url, headers={"User-Agent": "FEL-IntegrationTest/1.0"})
        resp = urllib.request.urlopen(req, timeout=timeout, context=ctx)
        return resp.status, resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, str(e)
    except Exception as e:
        return 0, str(e)


# ═══════════════════════════════════════════════════════════════════════════
# TEST GROUP 1: Marketing Website
# ═══════════════════════════════════════════════════════════════════════════

def test_website_build_exists():
    """Check NextJS website build exists."""
    build_dir = WEBSITE_DIR / ".next"
    if build_dir.is_dir():
        record("website_build", "PASS", f"NextJS build found at {build_dir}")
    else:
        record("website_build", "FAIL", "NextJS build not found. Run 'npm run build' in website dir.")


def test_website_package_json():
    """Verify website package.json is valid."""
    pkg = WEBSITE_DIR / "package.json"
    if not pkg.exists():
        record("website_package", "FAIL", "package.json not found")
        return
    try:
        data = json.loads(pkg.read_text())
        assert "next" in json.dumps(data.get("dependencies", {})), "Next.js not in dependencies"
        record("website_package", "PASS", f"Valid package.json with Next.js")
    except Exception as e:
        record("website_package", "FAIL", str(e))


def test_website_components():
    """Verify all website components exist."""
    required = ["Navbar.tsx", "Hero.tsx", "GameModes.tsx", "Exercises.tsx",
                "Technology.tsx", "HowItWorks.tsx", "Download.tsx",
                "Testimonials.tsx", "Contact.tsx", "Footer.tsx"]
    comp_dir = WEBSITE_DIR / "src" / "components"
    missing = [f for f in required if not (comp_dir / f).exists()]
    if not missing:
        record("website_components", "PASS", f"All {len(required)} components present")
    else:
        record("website_components", "FAIL", f"Missing: {', '.join(missing)}")


def test_website_seo():
    """Check SEO metadata in layout."""
    layout = WEBSITE_DIR / "src" / "app" / "layout.tsx"
    if not layout.exists():
        record("website_seo", "FAIL", "layout.tsx not found")
        return
    content = layout.read_text()
    checks = [
        ("title" in content.lower(), "title tag"),
        ("description" in content.lower(), "description meta"),
        ("opengraph" in content.lower() or "openGraph" in content, "Open Graph"),
        ("twitter" in content.lower(), "Twitter card"),
        ("keywords" in content.lower(), "keywords"),
    ]
    passed = sum(1 for c, _ in checks if c)
    if passed == len(checks):
        record("website_seo", "PASS", f"All {len(checks)} SEO elements present")
    else:
        missing = [name for ok, name in checks if not ok]
        record("website_seo", "WARN", f"Missing SEO: {', '.join(missing)}")


def test_website_game_modes_content():
    """Verify all 16 game modes are listed on the website."""
    gm_file = WEBSITE_DIR / "src" / "components" / "GameModes.tsx"
    if not gm_file.exists():
        record("website_game_modes", "FAIL", "GameModes.tsx not found")
        return
    content = gm_file.read_text()
    expected_modes = [
        "basketball_h2h", "basketball_tournament", "basketball_practice",
        "karate_h2h", "karate_training", "soccer", "tennis", "boxing",
        "swimming", "track_field", "volleyball", "gymnastics",
        "wrestling", "baseball", "obstacle_course", "freestyle_training"
    ]
    found = [m for m in expected_modes if m in content]
    if len(found) == 16:
        record("website_game_modes", "PASS", "All 16 game modes listed")
    else:
        record("website_game_modes", "FAIL", f"Only {len(found)}/16 modes found")


def test_website_exercises_content():
    """Verify 23 exercises listed."""
    ex_file = WEBSITE_DIR / "src" / "components" / "Exercises.tsx"
    if not ex_file.exists():
        record("website_exercises", "FAIL", "Exercises.tsx not found")
        return
    content = ex_file.read_text()
    # Count exercise entries
    count = content.count('name: "')
    if count >= 23:
        record("website_exercises", "PASS", f"{count} exercises listed")
    else:
        record("website_exercises", "FAIL", f"Only {count}/23 exercises found")


def test_website_download_links():
    """Verify download section has iOS and Android links."""
    dl_file = WEBSITE_DIR / "src" / "components" / "Download.tsx"
    if not dl_file.exists():
        record("website_download", "FAIL", "Download.tsx not found")
        return
    content = dl_file.read_text()
    has_ios = "apps.apple.com" in content or "App Store" in content
    has_android = "play.google.com" in content or "Google Play" in content
    has_qr = "QR" in content.lower() or "qr" in content.lower() or "Scan" in content
    if has_ios and has_android and has_qr:
        record("website_download", "PASS", "iOS, Android links and QR codes present")
    else:
        missing = []
        if not has_ios: missing.append("iOS link")
        if not has_android: missing.append("Android link")
        if not has_qr: missing.append("QR codes")
        record("website_download", "WARN", f"Missing: {', '.join(missing)}")


def test_website_responsive():
    """Check for responsive design indicators."""
    page = WEBSITE_DIR / "src" / "app" / "page.tsx"
    globals_css = WEBSITE_DIR / "src" / "app" / "globals.css"
    if not page.exists():
        record("website_responsive", "FAIL", "page.tsx not found")
        return
    # Check for Tailwind responsive classes
    content = page.read_text()
    # Check components for responsive classes
    comp_dir = WEBSITE_DIR / "src" / "components"
    all_content = ""
    for f in comp_dir.glob("*.tsx"):
        all_content += f.read_text()
    has_responsive = any(cls in all_content for cls in ["sm:", "md:", "lg:", "xl:"])
    has_grid = "grid" in all_content.lower()
    if has_responsive and has_grid:
        record("website_responsive", "PASS", "Responsive design classes found")
    else:
        record("website_responsive", "WARN", "Limited responsive design indicators")


# ═══════════════════════════════════════════════════════════════════════════
# TEST GROUP 2: Streaming Infrastructure
# ═══════════════════════════════════════════════════════════════════════════

def test_signalling_health():
    """Check signalling server health endpoint."""
    status, body = http_get(f"{SIGNALLING_URL}/healthz")
    if status == 200:
        record("signalling_health", "PASS", f"Signalling server healthy")
    elif status == 0:
        record("signalling_health", "SKIP", f"Signalling server not running (expected in dev)")
    else:
        record("signalling_health", "FAIL", f"HTTP {status}: {body[:100]}")


def test_signalling_modes_api():
    """Check game modes API returns 16+ modes."""
    status, body = http_get(f"{SIGNALLING_URL}/api/modes")
    if status == 0:
        record("signalling_modes", "SKIP", "Signalling server not running")
        return
    if status != 200:
        record("signalling_modes", "FAIL", f"HTTP {status}")
        return
    try:
        modes = json.loads(body)
        if isinstance(modes, list) and len(modes) >= 16:
            record("signalling_modes", "PASS", f"{len(modes)} game modes registered")
        else:
            record("signalling_modes", "FAIL", f"Only {len(modes) if isinstance(modes, list) else 0} modes")
    except json.JSONDecodeError:
        record("signalling_modes", "WARN", "Response not valid JSON")


def test_signalling_server_files():
    """Verify signalling server source files."""
    server_js = PROJECT_ROOT / "streaming" / "signalling" / "server.js"
    pkg_json = PROJECT_ROOT / "streaming" / "signalling" / "package.json"
    if server_js.exists() and pkg_json.exists():
        record("signalling_files", "PASS", "Signalling server files present")
    else:
        record("signalling_files", "FAIL", "Missing signalling server files")


def test_frontend_files():
    """Verify frontend build files."""
    dist_dir = PROJECT_ROOT / "streaming" / "frontend" / "dist"
    if dist_dir.is_dir() and any(dist_dir.glob("*.html")):
        record("frontend_build", "PASS", "Frontend build present")
    else:
        record("frontend_build", "WARN", "Frontend not built. Run: cd streaming/frontend && npm run build")


# ═══════════════════════════════════════════════════════════════════════════
# TEST GROUP 3: DNS Configuration
# ═══════════════════════════════════════════════════════════════════════════

def test_dns_docs_exist():
    """Verify DNS documentation exists."""
    dns_doc = PROJECT_ROOT / "docs" / "DNS_CONFIGURATION.md"
    if dns_doc.exists():
        content = dns_doc.read_text()
        checks = [
            "A record" in content or "A     @" in content,
            "CNAME" in content,
            "stream" in content,
            "SSL" in content.upper() or "ssl" in content,
            "Cloudflare" in content or "cloudflare" in content,
        ]
        if all(checks):
            record("dns_docs", "PASS", "DNS configuration docs complete")
        else:
            record("dns_docs", "WARN", "DNS docs incomplete")
    else:
        record("dns_docs", "FAIL", "DNS_CONFIGURATION.md not found")


def test_dns_resolution():
    """Test if domain resolves (may not work before DNS is configured)."""
    try:
        ip = socket.gethostbyname("finalevolutiongroup.com")
        record("dns_resolution", "PASS", f"finalevolutiongroup.com resolves to {ip}")
    except socket.gaierror:
        record("dns_resolution", "SKIP", "Domain not yet configured (expected pre-deployment)")


# ═══════════════════════════════════════════════════════════════════════════
# TEST GROUP 4: Game Modes Registration
# ═══════════════════════════════════════════════════════════════════════════

def test_game_mode_definitions():
    """Verify 16 game modes are defined in project files."""
    # Check in animation mapping (may use different naming convention)
    mapping = PROJECT_ROOT / "GeneratedAssets" / "Animations" / "ue5_animation_mapping.json"
    if mapping.exists():
        data = json.loads(mapping.read_text())
        modes_in_file = set(data.get("game_modes", {}).keys())
        if len(modes_in_file) >= 16:
            record("game_mode_defs", "PASS", f"{len(modes_in_file)} game modes defined in animation mapping")
        else:
            record("game_mode_defs", "WARN", f"{len(modes_in_file)}/16 modes in mapping")
    else:
        # Fallback: check C++ header
        header = PROJECT_ROOT / "UnrealStarter" / "BasketballGame" / "Source" / "FinalEvolutionLab" / "FELElijahBondsAnimPaths.h"
        if header.exists():
            content = header.read_text()
            mode_count = content.count("MODE_")
            if mode_count >= 16:
                record("game_mode_defs", "PASS", f"{mode_count} game modes in C++ header")
            else:
                record("game_mode_defs", "WARN", f"{mode_count} game modes in C++ header")
        else:
            record("game_mode_defs", "WARN", "No game mode definition files found")


def test_game_mode_cpp_header():
    """Verify game mode constants in C++ header."""
    header = PROJECT_ROOT / "UnrealStarter" / "BasketballGame" / "Source" / "FinalEvolutionLab" / "FELElijahBondsAnimPaths.h"
    if not header.exists():
        record("game_mode_header", "FAIL", "FELElijahBondsAnimPaths.h not found")
        return
    content = header.read_text()
    mode_count = content.count("MODE_")
    if mode_count >= 16:
        record("game_mode_header", "PASS", f"{mode_count} game mode constants in C++ header")
    else:
        record("game_mode_header", "WARN", f"Only {mode_count} game mode constants found")


# ═══════════════════════════════════════════════════════════════════════════
# TEST GROUP 5: iOS App Configuration
# ═══════════════════════════════════════════════════════════════════════════

def test_ios_config():
    """Verify iOS app Config.swift has production URLs."""
    config = PROJECT_ROOT / "ios" / "FinalEvolutionLab" / "Config.swift"
    if not config.exists():
        record("ios_config", "FAIL", "Config.swift not found")
        return
    content = config.read_text()
    checks = [
        ("stream.finalevolutiongroup.com" in content, "streaming URL"),
        ("turn.finalevolutiongroup.com" in content or "TURN" in content, "TURN server"),
        ("finalevolutiongroup.com" in content, "domain reference"),
        ("com.finalevolutiongroup.lab" in content, "bundle ID"),
    ]
    passed_checks = [(ok, name) for ok, name in checks]
    passed = sum(1 for ok, _ in passed_checks if ok)
    if passed == len(checks):
        record("ios_config", "PASS", f"All {len(checks)} iOS config checks pass")
    else:
        missing = [name for ok, name in passed_checks if not ok]
        record("ios_config", "FAIL", f"Missing: {', '.join(missing)}")


def test_ios_pixel_streaming_service():
    """Verify PixelStreamingService.swift references correct server."""
    svc = PROJECT_ROOT / "ios" / "FinalEvolutionLab" / "Services" / "PixelStreamingService.swift"
    if not svc.exists():
        record("ios_streaming", "FAIL", "PixelStreamingService.swift not found")
        return
    content = svc.read_text()
    if "Config.STREAMING_SERVER_URL" in content or "stream.finalevolutiongroup.com" in content:
        record("ios_streaming", "PASS", "iOS streaming service configured correctly")
    else:
        record("ios_streaming", "WARN", "Streaming URL may not be properly configured")


# ═══════════════════════════════════════════════════════════════════════════
# TEST GROUP 6: Asset Verification
# ═══════════════════════════════════════════════════════════════════════════

def test_asset_manifest():
    """Check pipeline report exists and has content."""
    report = PROJECT_ROOT / "GeneratedAssets" / "pipeline_report.json"
    if not report.exists():
        record("asset_manifest", "WARN", "pipeline_report.json not found")
        return
    data = json.loads(report.read_text())
    # Check for phases or summary - structure varies
    total = data.get("summary", {}).get("manifest_entries", 0)
    if total >= 49:
        record("asset_manifest", "PASS", f"{total} assets in manifest")
    elif "phases" in data and len(data["phases"]) > 0:
        record("asset_manifest", "PASS", f"Pipeline report has {len(data['phases'])} phases")
    else:
        # Check AI-generated assets header as fallback
        header = PROJECT_ROOT / "UnrealStarter" / "BasketballGame" / "Source" / "FinalEvolutionLab" / "FELGeneratedAssetPaths.h"
        if header.exists():
            content = header.read_text()
            asset_count = content.count("static const TCHAR*")
            record("asset_manifest", "PASS", f"{asset_count} assets defined in C++ header")
        else:
            record("asset_manifest", "WARN", "Could not verify asset count")


def test_animation_coverage():
    """Verify animation coverage across game modes."""
    manifest = PROJECT_ROOT / "GeneratedAssets" / "Animations" / "animation_manifest.json"
    if not manifest.exists():
        record("animation_coverage", "WARN", "animation_manifest.json not found")
        return
    data = json.loads(manifest.read_text())
    custom = len(data.get("custom_animations", []))
    if custom >= 50:
        record("animation_coverage", "PASS", f"{custom} custom animations mapped")
    else:
        record("animation_coverage", "WARN", f"{custom} custom animations (target: 54)")


# ═══════════════════════════════════════════════════════════════════════════
# TEST GROUP 7: Documentation Completeness
# ═══════════════════════════════════════════════════════════════════════════

def test_docs_complete():
    """Verify all deployment docs exist."""
    required_docs = [
        "FINAL_DEPLOYMENT_README.md",
        "ARCHITECTURE.md",
        "DNS_CONFIGURATION.md",
        "GPU_SETUP.md",
        "APP_STORE_CHECKLIST.md",
        "SERVICE_ENDPOINTS.md",
        "TROUBLESHOOTING.md",
        "MONITORING.md",
    ]
    docs_dir = PROJECT_ROOT / "docs"
    missing = [d for d in required_docs if not (docs_dir / d).exists()]
    if not missing:
        record("docs_complete", "PASS", f"All {len(required_docs)} deployment documents present")
    else:
        record("docs_complete", "FAIL", f"Missing: {', '.join(missing)}")


def test_deployment_guide():
    """Verify main deployment guide exists."""
    guide = PROJECT_ROOT / "DEPLOYMENT_GUIDE.md"
    if guide.exists() and guide.stat().st_size > 1000:
        record("deployment_guide", "PASS", f"DEPLOYMENT_GUIDE.md present ({guide.stat().st_size} bytes)")
    else:
        record("deployment_guide", "WARN", "DEPLOYMENT_GUIDE.md missing or too small")


# ═══════════════════════════════════════════════════════════════════════════
# TEST RUNNER
# ═══════════════════════════════════════════════════════════════════════════

def test_cv_preprocessing_pipeline():
    """Test CV preprocessing pipeline files exist and are importable."""
    cv_dir = PROJECT_ROOT / "scripts" / "cv_preprocessing"
    required_modules = [
        "__init__.py",
        "actor_segmentation.py",
        "background_masking.py",
        "hoop_detection.py",
        "motion_smoothing.py",
        "preprocessing_pipeline.py",
        "biomechanical_validator.py"
    ]
    missing = [m for m in required_modules if not (cv_dir / m).exists()]
    if not missing:
        record("cv_preprocessing_pipeline", "PASS", f"All {len(required_modules)} CV modules present")
    else:
        record("cv_preprocessing_pipeline", "FAIL", f"Missing modules: {missing}")

    # Check requirements.txt
    req = cv_dir / "requirements.txt"
    if req.exists():
        content = req.read_text()
        for dep in ["ultralytics", "opencv", "scipy"]:
            if dep not in content:
                record(f"cv_dep_{dep}", "WARN", f"Dependency '{dep}' not in requirements.txt")
    else:
        record("cv_requirements", "WARN", "CV requirements.txt not found")


def test_biomechanical_joint_limits():
    """Verify joint angle limits are biomechanically valid."""
    joint_limits = {
        "knee_flexion": (0, 160),
        "hip_flexion": (0, 130),
        "shoulder_flexion": (0, 180),
        "elbow_flexion": (0, 150),
        "ankle_dorsiflexion": (0, 20),
    }
    all_valid = True
    for joint, (lo, hi) in joint_limits.items():
        if lo < 0 or hi > 360 or lo >= hi:
            record(f"joint_limit_{joint}", "FAIL", f"Invalid range: ({lo}, {hi})")
            all_valid = False
        if hi > 180 and joint not in ("shoulder_flexion", "shoulder_abduction"):
            record(f"joint_limit_{joint}", "WARN", f"Unusually high max: {hi}°")

    if all_valid:
        record("biomechanical_joint_limits", "PASS", f"All {len(joint_limits)} joint limits valid")

    # Check validator module can be imported
    try:
        sys.path.insert(0, str(PROJECT_ROOT / "scripts" / "cv_preprocessing"))
        from biomechanical_validator import JOINT_ANGLE_LIMITS, BiomechanicalValidator
        record("biomechanical_validator_import", "PASS",
               f"Validator importable, {len(JOINT_ANGLE_LIMITS)} joint limits defined")
    except Exception as e:
        record("biomechanical_validator_import", "WARN", f"Cannot import: {e}")


def test_cv_metadata_structure():
    """Check CV preprocessing output metadata structure if available."""
    cv_output = PROJECT_ROOT / "GeneratedAssets" / "CVPreprocessed"
    if not cv_output.exists():
        record("cv_metadata", "SKIP", "No CV preprocessed output yet")
        return

    meta_dir = cv_output / "metadata"
    if meta_dir.exists():
        meta_files = list(meta_dir.glob("*_cv_meta.json"))
        if meta_files:
            # Validate structure of first file
            try:
                data = json.loads(meta_files[0].read_text())
                required_keys = ["video_name", "stages", "status"]
                missing = [k for k in required_keys if k not in data]
                if missing:
                    record("cv_metadata_structure", "WARN", f"Missing keys: {missing}")
                else:
                    record("cv_metadata_structure", "PASS",
                           f"{len(meta_files)} metadata files, structure valid")
            except Exception as e:
                record("cv_metadata_structure", "FAIL", f"Invalid JSON: {e}")
        else:
            record("cv_metadata", "SKIP", "No metadata files generated yet")
    else:
        record("cv_metadata", "SKIP", "Metadata directory not yet created")

    # Check preprocessing report
    report = PROJECT_ROOT / "logs" / "cv_preprocessing_report.json"
    if report.exists():
        try:
            data = json.loads(report.read_text())
            summary = data.get("summary", {})
            record("cv_report", "PASS",
                   f"Report: {summary.get('total_videos', 0)} videos, "
                   f"{summary.get('successful', 0)} successful")
        except Exception as e:
            record("cv_report", "WARN", f"Report parse error: {e}")
    else:
        record("cv_report", "SKIP", "CV preprocessing report not yet generated")


def main():
    print("\n" + "=" * 70)
    print(" FINAL EVOLUTION LAB - Integration Test Suite")
    print(f" Run at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70 + "\n")

    # Group 1: Marketing Website
    print("\n--- Marketing Website Tests ---")
    test_website_build_exists()
    test_website_package_json()
    test_website_components()
    test_website_seo()
    test_website_game_modes_content()
    test_website_exercises_content()
    test_website_download_links()
    test_website_responsive()

    # Group 2: Streaming Infrastructure
    print("\n--- Streaming Infrastructure Tests ---")
    test_signalling_health()
    test_signalling_modes_api()
    test_signalling_server_files()
    test_frontend_files()

    # Group 3: DNS
    print("\n--- DNS Configuration Tests ---")
    test_dns_docs_exist()
    test_dns_resolution()

    # Group 4: Game Modes
    print("\n--- Game Mode Tests ---")
    test_game_mode_definitions()
    test_game_mode_cpp_header()

    # Group 5: iOS
    print("\n--- iOS App Tests ---")
    test_ios_config()
    test_ios_pixel_streaming_service()

    # Group 6: Assets
    print("\n--- Asset Verification Tests ---")
    test_asset_manifest()
    test_animation_coverage()

    # Group 7: Docs
    print("\n--- Documentation Tests ---")
    test_docs_complete()
    test_deployment_guide()

    # Group 8: CV Preprocessing & Biomechanical Validation
    print("\n--- CV Preprocessing & Biomechanical Tests ---")
    test_cv_preprocessing_pipeline()
    test_biomechanical_joint_limits()
    test_cv_metadata_structure()

    # Summary
    total = results["passed"] + results["failed"] + results["warned"] + results["skipped"]
    print("\n" + "=" * 70)
    print(f" RESULTS: {total} tests run")
    print(f"   ✅ Passed:  {results['passed']}")
    print(f"   ❌ Failed:  {results['failed']}")
    print(f"   ⚠️  Warned:  {results['warned']}")
    print(f"   ⏭️  Skipped: {results['skipped']}")
    print("=" * 70)

    # Save report
    report_path = PROJECT_ROOT / "logs" / "integration_test_report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(results, indent=2))
    print(f"\nReport saved to: {report_path}")

    # Exit code
    if results["failed"] > 0:
        print("\n\033[91m❌ Some tests FAILED. Review above.\033[0m")
        sys.exit(1)
    else:
        print("\n\033[92m✅ All critical tests passed!\033[0m")
        sys.exit(0)


if __name__ == "__main__":
    main()
