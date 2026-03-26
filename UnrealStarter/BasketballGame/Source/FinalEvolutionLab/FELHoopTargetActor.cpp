// Copyright (c) Final Evolution Lab.

#include "FELHoopTargetActor.h"
#include "Components/SceneComponent.h"

AFELHoopTargetActor::AFELHoopTargetActor()
{
	PrimaryActorTick.bCanEverTick = false;
	RootScene = CreateDefaultSubobject<USceneComponent>(TEXT("RootScene"));
	SetRootComponent(RootScene);
}

FVector AFELHoopTargetActor::GetMagnetTargetLocation_Implementation() const
{
	return GetActorLocation();
}

float AFELHoopTargetActor::GetPredictiveMagnetStrength_Implementation(const float NeuralDrive0to100) const
{
	const float D = FMath::Clamp(NeuralDrive0to100, 0.f, 100.f);
	if (D < 75.f)
	{
		return 0.f;
	}
	return EliteMagnetStrengthMax * FMath::Pow((D - 75.f) / 25.f, 2.f);
}
