// Copyright (c) Final Evolution Lab.

#include "UFELLandingIKComponent.h"

UFELLandingIKComponent::UFELLandingIKComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
}

void UFELLandingIKComponent::SetKineticHeats(float AnkleHeat01, float KneeHeat01)
{
	CachedAnkle01 = FMath::Clamp(AnkleHeat01, 0.f, 1.f);
	CachedKnee01 = FMath::Clamp(KneeHeat01, 0.f, 1.f);
}

void UFELLandingIKComponent::ApplyLandingFromScan(bool bStickLandingMode, float AnkleHeat01, float KneeHeat01)
{
	if (!bStickLandingMode)
	{
		return;
	}
	const float A = FMath::Clamp(AnkleHeat01, 0.f, 1.f);
	const float K = FMath::Clamp(KneeHeat01, 0.f, 1.f);
	// Worst chain dominates; knee heat biases frontal wobble (patellar line).
	const float Combined = FMath::Clamp(0.45f * A + 0.55f * K, 0.f, 1.f);
	CurrentWobblePitchDeg = Combined * MaxLandingWobblePitchDeg;
	CurrentPelvisShiftCM = Combined * MaxPelvisShiftCM;
}

void UFELLandingIKComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
	const float Decay = FMath::Exp(-WobbleDecayPerSecond * DeltaTime);
	CurrentWobblePitchDeg *= Decay;
	CurrentPelvisShiftCM *= Decay;
	if (CurrentWobblePitchDeg < 0.02f)
	{
		CurrentWobblePitchDeg = 0.f;
	}
	if (CurrentPelvisShiftCM < 0.02f)
	{
		CurrentPelvisShiftCM = 0.f;
	}
}
