// Copyright (c) Final Evolution Lab.

#include "FELPlatformPaths.h"
#include "HAL/PlatformFilemanager.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"

FString FELPlatformPaths::GetFELDataDirectory()
{
	const FString Dir = FPaths::ProjectSavedDir() / TEXT("FEL");
	IPlatformFile& PF = FPlatformFileManager::Get().GetPlatformFile();
	if (!PF.DirectoryExists(*Dir))
	{
		PF.CreateDirectoryTree(*Dir);
	}
	return Dir;
}

void FELPlatformPaths::GetReadinessSnapshotCandidatePaths(TArray<FString>& OutOrderedPaths)
{
	OutOrderedPaths.Reset();
	OutOrderedPaths.Add(GetFELDataDirectory() / TEXT("readiness_snapshot.json"));
	OutOrderedPaths.Add(FPaths::ProjectContentDir() / TEXT("FEL/Config/readiness_snapshot.json"));
}

bool FELPlatformPaths::HasCompletedLabOnboarding()
{
	return FPaths::FileExists(GetLabOnboardingFlagPath());
}

void FELPlatformPaths::SetLabOnboardingCompleted()
{
	const FString Path = GetLabOnboardingFlagPath();
	const FString Dir = FPaths::GetPath(Path);
	IPlatformFile& PF = FPlatformFileManager::Get().GetPlatformFile();
	if (!PF.DirectoryExists(*Dir))
	{
		PF.CreateDirectoryTree(*Dir);
	}
	FFileHelper::SaveStringToFile(TEXT("1"), *Path);
}
