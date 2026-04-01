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
	// No HTTPS backend in this module — do not leave `bPendingCloudSync` stuck true.
	// When wiring: set true → async POST → clear on success/failure; optionally write `last_cloud_sync_timestamp` beside JSON.
	bPendingCloudSync = false;
}

void UFELCloudSyncSubsystem::RequestDownloadReadinessSnapshotToDisk()
{
	// Same: no remote GET until backend is integrated; callers must not block on HasPendingCloudSync().
	bPendingCloudSync = false;
	// When wiring: GET → write `FELPlatformPaths::GetFELDataDirectory()/readiness_snapshot.json` → notify
	// `UFELNeuroMechanicBridgeSubsystem` / `UFELAvatarSubsystem` to reload readiness.
}
