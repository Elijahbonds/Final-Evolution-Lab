// Copyright (c) Final Evolution Lab.
// Future: upload/download `readiness_snapshot.json` from `FELPlatformPaths::GetFELDataDirectory()` to Firestore or S3.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELCloudSyncSubsystem.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFELCloudSyncSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** Read local `…/FEL/readiness_snapshot.json` and enqueue secure cloud upload (stub until backend is wired). */
	UFUNCTION(BlueprintCallable, Category = "FEL|CloudSync")
	void RequestUploadReadinessSnapshotFromDisk();

	/** Pull remote twin JSON into the same FEL data path (stub until backend is wired). */
	UFUNCTION(BlueprintCallable, Category = "FEL|CloudSync")
	void RequestDownloadReadinessSnapshotToDisk();

	UFUNCTION(BlueprintPure, Category = "FEL|CloudSync")
	bool HasPendingCloudSync() const { return bPendingCloudSync; }

private:
	bool bPendingCloudSync = false;
};
