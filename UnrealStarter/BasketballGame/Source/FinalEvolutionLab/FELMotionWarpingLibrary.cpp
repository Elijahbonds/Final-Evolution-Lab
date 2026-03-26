// Copyright (c) Final Evolution Lab.

#include "FELMotionWarpingLibrary.h"
#include "FELArenaDifficultyScaling.h"
#include "MotionWarpingComponent.h"

const FName FELMotionWarping::JumpAlignTargetName(TEXT("FEL_JumpAlign"));
const FName FELMotionWarping::KickAlignTargetName(TEXT("FEL_KickAlign"));
const FName FELMotionWarping::StrikeAlignTargetName(TEXT("FEL_StrikeAlign"));

void FELMotionWarping::SetJumpWarpToTarget(
	UMotionWarpingComponent* MotionWarping,
	const FVector& WarpWorldLocation,
	const FName& WarpTargetName)
{
	if (!MotionWarping)
	{
		return;
	}
	MotionWarping->AddOrUpdateWarpTargetFromLocation(WarpTargetName, WarpWorldLocation);
}

void FELMotionWarping::ClearWarpTarget(UMotionWarpingComponent* MotionWarping, const FName& WarpTargetName)
{
	if (!MotionWarping)
	{
		return;
	}
	MotionWarping->RemoveWarpTarget(WarpTargetName);
}

FVector FELMotionWarping::ComputeDunkWarpLocation(
	const FVector& HoopTargetWorldLocation,
	const FVector& PlayerLocation,
	float DunkJumpWarpZOffsetCM)
{
	FVector L = HoopTargetWorldLocation;
	L.Z += DunkJumpWarpZOffsetCM;
	return L;
}

FVector FELMotionWarping::ComputeDunkWarpLocationWithPRQ(
	const FVector& HoopTargetWorldLocation,
	const FVector& PlayerLocation,
	float DunkJumpWarpZOffsetCM,
	float PRQ0to100,
	float GearMagnetismMult)
{
	const FVector Ideal = ComputeDunkWarpLocation(HoopTargetWorldLocation, PlayerLocation, DunkJumpWarpZOffsetCM);
	const FVector Delta = Ideal - PlayerLocation;
	const FVector WeakNatural = PlayerLocation + Delta * 0.48f;
	const float M = FMath::Clamp(
		FELArenaDifficultyScaling::MotionWarpMagnetismFromPRQ(PRQ0to100) * FMath::Clamp(GearMagnetismMult, 1.f, 1.06f),
		0.f,
		1.f);
	return FMath::Lerp(WeakNatural, Ideal, M);
}

void UFELMotionWarpingLibrary::SetJumpWarpTarget(
	UMotionWarpingComponent* MotionWarping,
	FVector WarpWorldLocation,
	FName WarpTargetName)
{
	if (WarpTargetName.IsNone())
	{
		WarpTargetName = FELMotionWarping::JumpAlignTargetName;
	}
	FELMotionWarping::SetJumpWarpToTarget(MotionWarping, WarpWorldLocation, WarpTargetName);
}

void UFELMotionWarpingLibrary::ClearWarpTarget(UMotionWarpingComponent* MotionWarping, FName WarpTargetName)
{
	FELMotionWarping::ClearWarpTarget(MotionWarping, WarpTargetName);
}

FVector UFELMotionWarpingLibrary::ComputeDunkWarpLocation(
	FVector HoopTargetWorldLocation,
	FVector PlayerLocation,
	float DunkJumpWarpZOffsetCM)
{
	return FELMotionWarping::ComputeDunkWarpLocation(HoopTargetWorldLocation, PlayerLocation, DunkJumpWarpZOffsetCM);
}

FVector UFELMotionWarpingLibrary::ComputeDunkWarpLocationWithPRQ(
	FVector HoopTargetWorldLocation,
	FVector PlayerLocation,
	float DunkJumpWarpZOffsetCM,
	float PRQ0to100,
	float GearMagnetismMult)
{
	return FELMotionWarping::ComputeDunkWarpLocationWithPRQ(
		HoopTargetWorldLocation,
		PlayerLocation,
		DunkJumpWarpZOffsetCM,
		PRQ0to100,
		GearMagnetismMult);
}

void FELMotionWarping::SetStrikeWarpToTarget(
	UMotionWarpingComponent* MotionWarping,
	const FVector& WarpWorldLocation,
	const FName& WarpTargetName)
{
	SetJumpWarpToTarget(MotionWarping, WarpWorldLocation, WarpTargetName);
}

void UFELMotionWarpingLibrary::SetStrikeWarpTarget(
	UMotionWarpingComponent* MotionWarping,
	FVector WarpWorldLocation,
	FName WarpTargetName)
{
	if (WarpTargetName.IsNone())
	{
		WarpTargetName = FELMotionWarping::StrikeAlignTargetName;
	}
	FELMotionWarping::SetStrikeWarpToTarget(MotionWarping, WarpWorldLocation, WarpTargetName);
}
