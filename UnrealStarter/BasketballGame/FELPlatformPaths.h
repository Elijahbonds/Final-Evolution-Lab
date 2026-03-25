// Copyright (c) Final Evolution Lab.
// Writable FEL root: iOS Documents/FEL (Swift PRQManager parity); desktop uses Saved/FEL.

#pragma once

#include "CoreMinimal.h"

struct FELPlatformPaths
{
	/** Primary data dir: iOS = Documents/FEL; other = ProjectSavedDir()/FEL. */
	static FString GetFELDataDirectory();

	/** readiness_snapshot.json search (first hit wins): Documents/FEL, Saved/FEL, Content/FEL/Config. */
	static void GetReadinessSnapshotCandidatePaths(TArray<FString>& OutOrderedPaths);

	static FString GetSessionResultsJsonPath() { return GetFELDataDirectory() / TEXT("session_results.json"); }

	static FString GetProgressionSaveJsonPath() { return GetFELDataDirectory() / TEXT("progression_session.json"); }

	static FString GetLabOnboardingFlagPath() { return GetFELDataDirectory() / TEXT("lab_onboarding_completed.flag"); }

	static bool HasCompletedLabOnboarding();
	static void SetLabOnboardingCompleted();
};
