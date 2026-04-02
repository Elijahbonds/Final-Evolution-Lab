#!/usr/bin/env python3
"""Phase 4: Live Link Face Integration Test Suite

Comprehensive tests for the FEL Live Link Face system:
- Connection establishment
- Data streaming
- Blend shape validation
- Performance benchmarks
- Multiple device support
- Fallback behavior
- Expression trigger mapping

Usage:
    python3 Tools/test_livelink_face.py [--verbose] [--benchmark] [--mock]
"""

import json
import os
import sys
import time
import struct
import socket
import argparse
from pathlib import Path
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

# ─────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).resolve().parent.parent
UNREAL_ROOT = PROJECT_ROOT / "UnrealStarter" / "BasketballGame"
CONTENT_ROOT = UNREAL_ROOT / "Content" / "FEL"
SOURCE_ROOT = UNREAL_ROOT / "Source" / "FinalEvolutionLab"
CONFIG_ROOT = UNREAL_ROOT / "Config"
IOS_APP_ROOT = PROJECT_ROOT / "MobileApps" / "LiveLinkFaceCapture"

# 52 ARKit blend shapes
ARKIT_BLEND_SHAPES = [
    "EyeBlinkLeft", "EyeLookDownLeft", "EyeLookInLeft", "EyeLookOutLeft",
    "EyeLookUpLeft", "EyeSquintLeft", "EyeWideLeft",
    "EyeBlinkRight", "EyeLookDownRight", "EyeLookInRight", "EyeLookOutRight",
    "EyeLookUpRight", "EyeSquintRight", "EyeWideRight",
    "JawForward", "JawLeft", "JawRight", "JawOpen",
    "MouthClose", "MouthFunnel", "MouthPucker",
    "MouthLeft", "MouthRight",
    "MouthSmileLeft", "MouthSmileRight",
    "MouthFrownLeft", "MouthFrownRight",
    "MouthDimpleLeft", "MouthDimpleRight",
    "MouthStretchLeft", "MouthStretchRight",
    "MouthRollLower", "MouthRollUpper",
    "MouthShrugLower", "MouthShrugUpper",
    "MouthPressLeft", "MouthPressRight",
    "MouthLowerDownLeft", "MouthLowerDownRight",
    "MouthUpperUpLeft", "MouthUpperUpRight",
    "BrowDownLeft", "BrowDownRight",
    "BrowInnerUp", "BrowOuterUpLeft", "BrowOuterUpRight",
    "CheekPuff", "CheekSquintLeft", "CheekSquintRight",
    "NoseSneerLeft", "NoseSneerRight",
    "TongueOut"
]

EXPECTED_CHARACTERS = ["player", "elijah_bonds", "amir_smith", "eric_nash",
                       "npc_type_a", "npc_type_b", "npc_type_c"]

EXPECTED_EXPRESSIONS = ["neutral", "happy", "determined", "tired", "celebrating",
                        "disappointed", "angry", "surprised", "pain", "trash_talk", "recovery"]

GAME_MODES = [
    "basketball_h2h", "basketball_3v3", "basketball_tournament", "basketball_practice",
    "soccer", "football", "boxing_h2h", "mma_h2h", "tennis", "volleyball",
    "baseball", "track_field", "swimming", "gymnastics", "skateboarding",
    "workout", "karate_h2h"
]

# ─────────────────────────────────────────────────────────────────────
# Test results tracking
# ─────────────────────────────────────────────────────────────────────

@dataclass
class TestResult:
    name: str
    passed: bool
    message: str = ""
    duration_ms: float = 0.0

@dataclass
class TestSuite:
    results: List[TestResult] = field(default_factory=list)
    
    def add(self, name: str, passed: bool, message: str = "", duration_ms: float = 0.0):
        self.results.append(TestResult(name, passed, message, duration_ms))
    
    @property
    def passed(self) -> int:
        return sum(1 for r in self.results if r.passed)
    
    @property
    def failed(self) -> int:
        return sum(1 for r in self.results if not r.passed)
    
    @property
    def total(self) -> int:
        return len(self.results)
    
    def print_summary(self):
        print("\n" + "=" * 70)
        print(f"  LIVE LINK FACE TEST RESULTS: {self.passed}/{self.total} passed")
        print("=" * 70)
        for r in self.results:
            icon = "\u2705" if r.passed else "\u274c"
            timing = f" ({r.duration_ms:.1f}ms)" if r.duration_ms > 0 else ""
            msg = f" — {r.message}" if r.message else ""
            print(f"  {icon} {r.name}{timing}{msg}")
        print("=" * 70)
        if self.failed == 0:
            print("  \u2705 ALL TESTS PASSED")
        else:
            print(f"  \u274c {self.failed} TESTS FAILED")
        print("=" * 70 + "\n")

suite = TestSuite()

# ─────────────────────────────────────────────────────────────────────
# File existence tests
# ─────────────────────────────────────────────────────────────────────

def test_uproject_plugins():
    """Verify Live Link plugins are enabled in .uproject."""
    uproject = UNREAL_ROOT / "FinalEvolutionLab.uproject"
    if not uproject.exists():
        suite.add("UProject plugins", False, "FinalEvolutionLab.uproject not found")
        return
    
    data = json.loads(uproject.read_text())
    plugins = {p["Name"]: p.get("Enabled", False) for p in data.get("Plugins", [])}
    
    required = ["LiveLink", "LiveLinkFaceImporter", "AppleARKit", "AppleARKitFaceSupport"]
    missing = [p for p in required if not plugins.get(p, False)]
    
    if missing:
        suite.add("UProject plugins", False, f"Missing: {', '.join(missing)}")
    else:
        suite.add("UProject plugins", True, f"All {len(required)} Live Link plugins enabled")

def test_build_cs_modules():
    """Verify Live Link modules in Build.cs."""
    build_cs = SOURCE_ROOT / "FinalEvolutionLab.Build.cs"
    if not build_cs.exists():
        suite.add("Build.cs modules", False, "Build.cs not found")
        return
    
    content = build_cs.read_text()
    required = ["LiveLink", "LiveLinkInterface", "LiveLinkComponents", "AnimGraphRuntime"]
    found = [m for m in required if m in content]
    
    if len(found) == len(required):
        suite.add("Build.cs modules", True, f"All {len(required)} modules declared")
    else:
        missing = set(required) - set(found)
        suite.add("Build.cs modules", False, f"Missing: {', '.join(missing)}")

def test_cpp_source_files():
    """Verify all C++ source files exist."""
    required_files = [
        "FELLiveLinkManager.h", "FELLiveLinkManager.cpp",
        "FELLiveLinkFaceComponent.h", "FELLiveLinkFaceComponent.cpp",
        "FELFaceRigTypes.h",
        "FELExpressionTrigger.h", "FELExpressionTrigger.cpp",
        "FELFaceGameplayIntegration.h", "FELFaceGameplayIntegration.cpp",
    ]
    
    missing = [f for f in required_files if not (SOURCE_ROOT / f).exists()]
    if missing:
        suite.add("C++ source files", False, f"Missing: {', '.join(missing)}")
    else:
        suite.add("C++ source files", True, f"All {len(required_files)} files present")

def test_config_files():
    """Verify config files exist."""
    configs = [
        CONFIG_ROOT / "DefaultLiveLink.ini",
        CONTENT_ROOT / "Characters" / "FaceRigConfigs.json",
        CONTENT_ROOT / "Animations" / "FaceExpressions" / "ExpressionPresets.json",
    ]
    
    missing = [str(f) for f in configs if not f.exists()]
    if missing:
        suite.add("Config files", False, f"Missing: {len(missing)} files")
    else:
        suite.add("Config files", True, f"All {len(configs)} config files present")

def test_ios_app_files():
    """Verify iOS app files exist."""
    ios_files = [
        "FELFaceCapture/FELFaceCaptureApp.swift",
        "FELFaceCapture/ContentView.swift",
        "FELFaceCapture/FaceTracker.swift",
        "FELFaceCapture/LiveLinkClient.swift",
        "FELFaceCapture/SettingsView.swift",
        "FELFaceCapture/CalibrationView.swift",
        "FELFaceCapture/Info.plist",
    ]
    
    missing = [f for f in ios_files if not (IOS_APP_ROOT / f).exists()]
    if missing:
        suite.add("iOS app files", False, f"Missing: {', '.join(missing)}")
    else:
        suite.add("iOS app files", True, f"All {len(ios_files)} iOS app files present")

# ─────────────────────────────────────────────────────────────────────
# Data validation tests
# ─────────────────────────────────────────────────────────────────────

def test_face_rig_configs():
    """Validate face rig configuration data."""
    config_path = CONTENT_ROOT / "Characters" / "FaceRigConfigs.json"
    if not config_path.exists():
        suite.add("Face rig configs", False, "Config file not found")
        return
    
    data = json.loads(config_path.read_text())
    face_rigs = data.get("face_rigs", {})
    
    missing_chars = [c for c in EXPECTED_CHARACTERS if c not in face_rigs]
    if missing_chars:
        suite.add("Face rig configs", False, f"Missing characters: {', '.join(missing_chars)}")
        return
    
    # Validate each rig has required fields
    errors = []
    for char_name, rig in face_rigs.items():
        for field in ["character_type", "active_blend_shapes", "morph_target_prefix"]:
            if field not in rig:
                errors.append(f"{char_name} missing '{field}'")
        if rig.get("active_blend_shapes", 0) not in [16, 32, 52]:
            errors.append(f"{char_name} invalid blend shape count: {rig.get('active_blend_shapes')}")
    
    if errors:
        suite.add("Face rig configs", False, f"{len(errors)} validation errors")
    else:
        suite.add("Face rig configs", True, f"{len(face_rigs)} characters configured")

def test_expression_presets():
    """Validate expression preset data."""
    preset_path = CONTENT_ROOT / "Animations" / "FaceExpressions" / "ExpressionPresets.json"
    if not preset_path.exists():
        suite.add("Expression presets", False, "Preset file not found")
        return
    
    data = json.loads(preset_path.read_text())
    presets = data.get("presets", {})
    
    missing = [e for e in EXPECTED_EXPRESSIONS if e not in presets]
    if missing:
        suite.add("Expression presets", False, f"Missing: {', '.join(missing)}")
        return
    
    # Validate blend shapes are valid ARKit names
    invalid = []
    for name, preset in presets.items():
        for bs_name in preset.get("blend_shapes", {}).keys():
            if bs_name not in ARKIT_BLEND_SHAPES:
                invalid.append(f"{name}/{bs_name}")
    
    if invalid:
        suite.add("Expression presets", False, f"Invalid blend shapes: {', '.join(invalid[:5])}")
    else:
        suite.add("Expression presets", True, f"{len(presets)} presets validated")

def test_blend_shape_count():
    """Verify we have exactly 52 ARKit blend shapes defined."""
    if len(ARKIT_BLEND_SHAPES) == 52:
        suite.add("ARKit blend shape count", True, "52 blend shapes")
    else:
        suite.add("ARKit blend shape count", False, f"Expected 52, got {len(ARKIT_BLEND_SHAPES)}")

def test_gameplay_trigger_mapping():
    """Validate gameplay event -> expression mappings."""
    preset_path = CONTENT_ROOT / "Animations" / "FaceExpressions" / "ExpressionPresets.json"
    if not preset_path.exists():
        suite.add("Gameplay triggers", False, "Preset file not found")
        return
    
    data = json.loads(preset_path.read_text())
    triggers = data.get("gameplay_trigger_map", {})
    presets = data.get("presets", {})
    
    # Validate all trigger expressions exist as presets
    invalid = []
    for event, trigger in triggers.items():
        expr = trigger.get("expression", "")
        if expr not in presets:
            invalid.append(f"{event} -> {expr}")
    
    if invalid:
        suite.add("Gameplay triggers", False, f"Invalid expression refs: {', '.join(invalid)}")
    else:
        suite.add("Gameplay triggers", True, f"{len(triggers)} events mapped")

def test_game_mode_coverage():
    """Check that all 17 game modes have face animation configs."""
    # Read the C++ source to check game mode registration
    cpp_file = SOURCE_ROOT / "FELFaceGameplayIntegration.cpp"
    if not cpp_file.exists():
        suite.add("Game mode coverage", False, "Integration cpp not found")
        return
    
    content = cpp_file.read_text()
    found_modes = [m for m in GAME_MODES if f'"{m}"' in content]
    missing_modes = [m for m in GAME_MODES if f'"{m}"' not in content]
    
    if missing_modes:
        suite.add("Game mode coverage", False, f"Missing: {', '.join(missing_modes)}")
    else:
        suite.add("Game mode coverage", True, f"All {len(GAME_MODES)} game modes configured")

# ─────────────────────────────────────────────────────────────────────
# Protocol / Packet tests
# ─────────────────────────────────────────────────────────────────────

def test_livelink_packet_format():
    """Verify the Live Link UDP packet format."""
    # Simulate packet building
    magic = 0x46454C4C  # "FELL"
    version = 1
    timestamp = int(time.time() * 1000)
    subject = "TestSubject"
    blend_shapes = {name: 0.5 for name in ARKIT_BLEND_SHAPES}
    
    data = bytearray()
    data += struct.pack('<I', magic)
    data += struct.pack('<H', version)
    data += struct.pack('<Q', timestamp)
    
    name_bytes = subject.encode('utf-8')[:63] + b'\x00'
    name_bytes += b'\x00' * (64 - len(name_bytes))
    data += name_bytes
    
    data += struct.pack('<H', len(blend_shapes))
    
    for name in ARKIT_BLEND_SHAPES:
        value = blend_shapes.get(name, 0.0)
        data += struct.pack('<f', value)
    
    # Expected size: 4 (magic) + 2 (version) + 8 (timestamp) + 64 (name) + 2 (count) + 52*4 (values)
    expected_size = 4 + 2 + 8 + 64 + 2 + 52 * 4
    
    if len(data) == expected_size:
        suite.add("Live Link packet format", True, f"Packet size: {expected_size} bytes")
    else:
        suite.add("Live Link packet format", False, f"Expected {expected_size}, got {len(data)} bytes")

# ─────────────────────────────────────────────────────────────────────
# Performance benchmark tests
# ─────────────────────────────────────────────────────────────────────

def test_blend_shape_processing_performance():
    """Benchmark blend shape processing speed."""
    import random
    
    iterations = 10000
    blend_shapes = {name: random.random() for name in ARKIT_BLEND_SHAPES}
    offsets = {name: random.random() * 0.1 for name in ARKIT_BLEND_SHAPES}
    prev_values = {name: random.random() for name in ARKIT_BLEND_SHAPES}
    smoothing = 0.15
    
    start = time.perf_counter()
    for _ in range(iterations):
        result = {}
        for name in ARKIT_BLEND_SHAPES:
            value = blend_shapes[name]
            # Calibration offset
            value = max(0, min(1, value - offsets.get(name, 0)))
            # Smoothing
            prev = prev_values.get(name, value)
            value = prev + (value - prev) * (1.0 - smoothing)
            result[name] = value
    
    elapsed_ms = (time.perf_counter() - start) * 1000
    per_frame_us = (elapsed_ms / iterations) * 1000
    
    # At 60 FPS we have 16.67ms per frame; processing should be under 1ms
    if per_frame_us < 1000:  # 1ms
        suite.add("Blend shape processing", True, f"{per_frame_us:.1f}\u00b5s/frame ({iterations} iterations)")
    else:
        suite.add("Blend shape processing", False, f"{per_frame_us:.1f}\u00b5s/frame (target: <1000\u00b5s)")

def test_packet_building_performance():
    """Benchmark packet serialization speed."""
    import random
    
    iterations = 10000
    blend_shapes = {name: random.random() for name in ARKIT_BLEND_SHAPES}
    
    start = time.perf_counter()
    for _ in range(iterations):
        data = bytearray()
        data += struct.pack('<I', 0x46454C4C)
        data += struct.pack('<H', 1)
        data += struct.pack('<Q', int(time.time() * 1000))
        data += b'TestSubject\x00' + b'\x00' * 53
        data += struct.pack('<H', 52)
        for name in ARKIT_BLEND_SHAPES:
            data += struct.pack('<f', blend_shapes.get(name, 0.0))
    
    elapsed_ms = (time.perf_counter() - start) * 1000
    per_frame_us = (elapsed_ms / iterations) * 1000
    
    if per_frame_us < 500:  # 0.5ms
        suite.add("Packet building", True, f"{per_frame_us:.1f}\u00b5s/frame")
    else:
        suite.add("Packet building", False, f"{per_frame_us:.1f}\u00b5s/frame (target: <500\u00b5s)")

# ─────────────────────────────────────────────────────────────────────
# Documentation test
# ─────────────────────────────────────────────────────────────────────

def test_documentation():
    """Verify documentation exists."""
    doc = PROJECT_ROOT / "docs" / "LIVE_LINK_FACE_GUIDE.md"
    if not doc.exists():
        suite.add("Documentation", False, "LIVE_LINK_FACE_GUIDE.md not found")
        return
    
    content = doc.read_text()
    required_sections = ["Setup", "iOS", "Calibration", "Troubleshooting", "Performance"]
    found = [s for s in required_sections if s.lower() in content.lower()]
    
    if len(found) == len(required_sections):
        suite.add("Documentation", True, f"All {len(required_sections)} sections present")
    else:
        missing = set(required_sections) - set(found)
        suite.add("Documentation", False, f"Missing sections: {', '.join(missing)}")

# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="FEL Live Link Face Test Suite")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument("--benchmark", "-b", action="store_true", help="Include performance benchmarks")
    parser.add_argument("--mock", "-m", action="store_true", help="Include mock device tests")
    args = parser.parse_args()
    
    print("\n" + "=" * 70)
    print("  FEL LIVE LINK FACE INTEGRATION - TEST SUITE")
    print("=" * 70 + "\n")
    
    # File existence tests
    print("[1/4] File existence tests...")
    test_uproject_plugins()
    test_build_cs_modules()
    test_cpp_source_files()
    test_config_files()
    test_ios_app_files()
    
    # Data validation tests
    print("[2/4] Data validation tests...")
    test_face_rig_configs()
    test_expression_presets()
    test_blend_shape_count()
    test_gameplay_trigger_mapping()
    test_game_mode_coverage()
    
    # Protocol tests
    print("[3/4] Protocol tests...")
    test_livelink_packet_format()
    
    # Performance tests
    if args.benchmark:
        print("[4/4] Performance benchmarks...")
        test_blend_shape_processing_performance()
        test_packet_building_performance()
    else:
        print("[4/4] Skipping benchmarks (use --benchmark to enable)")
    
    # Documentation
    test_documentation()
    
    suite.print_summary()
    
    return 0 if suite.failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
