// Copyright (c) Final Evolution Lab.
// Future: upload/download `readiness_snapshot.json` from Documents/FEL to Firestore or S3 for cross-device Digital Twin persistence.

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

	/** Read local `Documents/FEL/readiness_snapshot.json` (iOS) and enqueue secure cloud upload (stub). */
	UFUNCTION(BlueprintCallable, Category = "FEL|CloudSync")
	void RequestUploadReadinessSnapshotFromDisk();

	/** Pull remote twin JSON into `Documents/FEL/readiness_snapshot.json` (stub). */
	UFUNCTION(BlueprintCallable, Category = "FEL|CloudSync")
	void RequestDownloadReadinessSnapshotToDisk();

	UFUNCTION(BlueprintPure, Category = "FEL|CloudSync")
	bool HasPendingCloudSync() const { return bPendingCloudSync; }

private:
	bool bPendingCloudSync = false;
};
