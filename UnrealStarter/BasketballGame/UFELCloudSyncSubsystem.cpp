// Copyright (c) Final Evolution Lab.

#include "UFELCloudSyncSubsystem.h"
#include "FELPlatformPaths.h"
#include "Misc/Paths.h"

void UFELCloudSyncSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
}

void UFELCloudSyncSubsystem::Deinitialize()
{
	Super::Deinitialize();
}

void UFELCloudSyncSubsystem::RequestUploadReadinessSnapshotFromDisk()
{
	const FString LocalPath = FELPlatformPaths::GetFELDataDirectory() / TEXT("readiness_snapshot.json");
	if (!FPaths::FileExists(LocalPath))
	{
		return;
	}
	bPendingCloudSync = true;
	// TODO: Read file bytes → HTTPS POST to signed S3 or Firestore REST with athlete-scoped token.
	// TODO: On success, clear bPendingCloudSync and optionally write `last_cloud_sync_timestamp` beside JSON.
}

void UFELCloudSyncSubsystem::RequestDownloadReadinessSnapshotToDisk()
{
	bPendingCloudSync = true;
	// TODO: GET from cloud → write to FELPlatformPaths::GetFELDataDirectory()/readiness_snapshot.json
	// TODO: Notify `FELNeuroMechanicBridgeSubsystem` / `UFELAvatarSubsystem` to reload ApplyReadiness.
}
