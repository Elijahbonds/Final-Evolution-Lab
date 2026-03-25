// Copyright (c) Final Evolution Lab.
// Transient rig for SceneCapture2D — positioned to frame the player avatar for PNG export to Swift.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "AFELAvatarSnapshotRig.generated.h"

class USceneCaptureComponent2D;

UCLASS()
class FINALEVOLUTIONLAB_API AFELAvatarSnapshotRig : public AActor
{
	GENERATED_BODY()

public:
	AFELAvatarSnapshotRig();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Snapshot")
	TObjectPtr<USceneCaptureComponent2D> Capture;
};
