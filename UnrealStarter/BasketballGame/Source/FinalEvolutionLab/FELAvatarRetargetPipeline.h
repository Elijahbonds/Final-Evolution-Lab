// Copyright (c) Final Evolution Lab.
// Scan-to-Avatar: assign an IK Retargeter asset (UE5 IK Rig plugin) so DeepMotion FBX lands on the Elijah Bonds rig with minimal foot slide.
// Create IK Rig + IK Retargeter in editor; assign soft references on mode data or here.

#pragma once

#include "CoreMinimal.h"
#include "UObject/SoftObjectPtr.h"
#include "FELAvatarRetargetPipeline.generated.h"

/**
 * Designer: point IKRetargeterAsset at your packaged `UIKRetargeter` (IK Rig plugin).
 * Combine with DeepMotion `root_at_origin` + Motion Warping for dunk alignment.
 */
USTRUCT(BlueprintType)
struct FFELAvatarRetargetProfile
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Retarget")
	TSoftObjectPtr<UObject> IKRetargeterAsset;

	/** When true, expect mocap processed with root-at-origin to reduce global drift before foot IK. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Retarget")
	bool bPreferRootAtOriginImport = true;
};
