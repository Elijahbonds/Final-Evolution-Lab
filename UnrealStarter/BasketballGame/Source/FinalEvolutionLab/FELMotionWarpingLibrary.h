// Copyright (c) Final Evolution Lab.
// Motion Warping alignment — procedural anchor to rim / goal / ball so mocap does not "skate" across the floor.

#pragma once

#include "CoreMinimal.h"
#include "FELMotionWarpingLibrary.generated.h"

class UMotionWarpingComponent;

class FELMotionWarping
{
public:
	/** Must match AnimNotifyState_MotionWarp / AnimBP sync point name for jump apex. */
	static FINALEVOLUTIONLAB_API const FName JumpAlignTargetName;

	static FINALEVOLUTIONLAB_API const FName KickAlignTargetName;

	static FINALEVOLUTIONLAB_API const FName StrikeAlignTargetName;

	/**
	 * Registers a world-space warp target on the Motion Warping component.
	 * Call on jump wind-up (before montage reaches sync frame) so the engine warps root to align hands/feet to target.
	 */
	static FINALEVOLUTIONLAB_API void SetJumpWarpToTarget(
		UMotionWarpingComponent* MotionWarping,
		const FVector& WarpWorldLocation,
		const FName& WarpTargetName = JumpAlignTargetName);

	static FINALEVOLUTIONLAB_API void ClearWarpTarget(UMotionWarpingComponent* MotionWarping, const FName& WarpTargetName);

	static FINALEVOLUTIONLAB_API FVector ComputeDunkWarpLocation(
		const FVector& HoopTargetWorldLocation,
		const FVector& PlayerLocation,
		float DunkJumpWarpZOffsetCM);

	/** Same as `ComputeDunkWarpLocation`, but PRQ < 60 weakens pull toward the rim (readiness-gated magnetism). */
	static FINALEVOLUTIONLAB_API FVector ComputeDunkWarpLocationWithPRQ(
		const FVector& HoopTargetWorldLocation,
		const FVector& PlayerLocation,
		float DunkJumpWarpZOffsetCM,
		float PRQ0to100,
		float GearMagnetismMult = 1.f);

	/** Strike / kick / volleyball — align warp to a world target (same component as jump). */
	static FINALEVOLUTIONLAB_API void SetStrikeWarpToTarget(
		UMotionWarpingComponent* MotionWarping,
		const FVector& WarpWorldLocation,
		const FName& WarpTargetName = StrikeAlignTargetName);
};

UCLASS()
class FINALEVOLUTIONLAB_API UFELMotionWarpingLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

	UFUNCTION(BlueprintCallable, Category = "FEL|MotionWarping")
	static void SetJumpWarpTarget(
		UMotionWarpingComponent* MotionWarping,
		FVector WarpWorldLocation,
		FName WarpTargetName);

	UFUNCTION(BlueprintCallable, Category = "FEL|MotionWarping")
	static void ClearWarpTarget(UMotionWarpingComponent* MotionWarping, FName WarpTargetName);

	UFUNCTION(BlueprintPure, Category = "FEL|MotionWarping")
	static FVector ComputeDunkWarpLocation(
		FVector HoopTargetWorldLocation,
		FVector PlayerLocation,
		float DunkJumpWarpZOffsetCM);

	UFUNCTION(BlueprintPure, Category = "FEL|MotionWarping", meta = (AdvancedDisplay = "GearMagnetismMult"))
	static FVector ComputeDunkWarpLocationWithPRQ(
		FVector HoopTargetWorldLocation,
		FVector PlayerLocation,
		float DunkJumpWarpZOffsetCM,
		float PRQ0to100,
		float GearMagnetismMult = 1.f);

	UFUNCTION(BlueprintCallable, Category = "FEL|MotionWarping")
	static void SetStrikeWarpTarget(
		UMotionWarpingComponent* MotionWarping,
		FVector WarpWorldLocation,
		FName WarpTargetName);
};
