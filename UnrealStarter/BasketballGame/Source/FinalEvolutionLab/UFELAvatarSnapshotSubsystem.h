// Copyright (c) Final Evolution Lab.
// 3D → Swift: SceneCapture2D PNG of the digital twin (with shard gear) for Athlete Cards.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELAvatarSnapshotSubsystem.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFELAvatarSnapshotSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	/** Capture the local player avatar to PNG and send bytes to iOS via `FELNativeBridge` (no-op elsewhere). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Snapshot")
	void CaptureAvatarPngAndSendToHost();

	UPROPERTY(EditAnywhere, Category = "FEL|Snapshot")
	int32 CaptureSize = 1024;

	/** Camera offset from character origin (local space before aim-at). */
	UPROPERTY(EditAnywhere, Category = "FEL|Snapshot")
	FVector CameraOffsetUU = FVector(280.f, 40.f, 140.f);
};
