// Copyright (c) Final Evolution Lab.
// Writable FEL root: UE sandbox `ProjectSavedDir()/FEL` on all platforms (iOS/macOS/desktop).
// On iOS the engine maps ProjectSavedDir into the app container — same APIs as desktop; use this for
// session_results.json, progression_session.json, readiness_snapshot.json, and lab_onboarding_completed.flag.

#pragma once

#include "CoreMinimal.h"

struct FELPlatformPaths
{
	/** Primary data dir: `ProjectSavedDir()/FEL` (created on demand). Session + progression + readiness JSON live here. */
	static FString GetFELDataDirectory();

	/** readiness_snapshot.json search (first hit wins): FEL data dir, then `Content/FEL/Config` (design-time default). */
	static void GetReadinessSnapshotCandidatePaths(TArray<FString>& OutOrderedPaths);

	static FString GetSessionResultsJsonPath() { return GetFELDataDirectory() / TEXT("session_results.json"); }

	static FString GetLastSessionResultJsonPath() { return GetFELDataDirectory() / TEXT("last_session_result.json"); }

	static FString GetProgressionSaveJsonPath() { return GetFELDataDirectory() / TEXT("progression_session.json"); }

	static FString GetLabOnboardingFlagPath() { return GetFELDataDirectory() / TEXT("lab_onboarding_completed.flag"); }

	static bool HasCompletedLabOnboarding();
	static void SetLabOnboardingCompleted();
};
