# Android AAB build status — Sprint 1 (nexus/ci-aa)

**Decision: no `build-aab.yml` workflow was created, because this repository
contains no Android project.** Inventing a Gradle build for a codebase that has
no Android sources would produce a fake artifact, which is explicitly out of
scope.

## Evidence (checked 2026-07-01, base `integration/nexus-aaa`)

- No `build.gradle`, `build.gradle.kts`, `settings.gradle`, or `gradlew`
  anywhere in the tree (`rg --glob '*.gradle*'` returns nothing).
- No `AndroidManifest.xml` outside of third-party/node_modules noise.
- Shipping target is iOS-only: Swift app (`FinalEvolutionLab/`,
  `FinalEvolutionLab.xcodeproj`) on top of the NEXUS C++ engine (`engine/`),
  cross-compiled per-SDK by `scripts/build-nexus-ios.sh`.

## What was produced instead

`.github/workflows/ios-archive-dry-run.yml` — a manually-triggered
(`workflow_dispatch`) iOS archive **dry run** that:

1. builds the NEXUS static libraries for the iOS SDK via
   `scripts/archive-ios-testflight.sh --dry-run`, and
2. uploads the preflight log + built `NexusPrebuilt/` libraries as artifacts.

It does **not** sign, export, or upload an IPA — signing certificates,
provisioning profiles, and `GoogleService-Info.plist` are secrets and are
intentionally not part of CI (see the repo hard rule on secrets; the dry-run
path uses `ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1`).

## If Android becomes a target later

Prerequisites before a real `build-aab.yml` can exist:

1. An actual Android project (Gradle wrapper, `app/` module, manifest).
2. NEXUS engine cross-compile toolchain for `aarch64-linux-android`
   (NDK toolchain file; the current CMake setup only handles Apple SDKs).
3. Upload keystore handling via GitHub secrets (`ANDROID_KEYSTORE_*`) —
   never committed.

Estimate: 2–3 engineer-weeks for a first bootable Android shell, excluding
engine renderer work (Vulkan path exists but is untested on Android).
