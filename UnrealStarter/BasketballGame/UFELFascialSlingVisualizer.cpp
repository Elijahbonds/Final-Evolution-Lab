// Copyright (c) Final Evolution Lab.

#include "UFELFascialSlingVisualizer.h"
#include "Materials/MaterialInstanceDynamic.h"

UFELFascialSlingVisualizer::UFELFascialSlingVisualizer()
{
	PrimaryComponentTick.bCanEverTick = true;
}

void UFELFascialSlingVisualizer::SetFascialSlingActive(bool bActive)
{
	bSlingActive = bActive;
}

void UFELFascialSlingVisualizer::ApplySFMAHeatmapCongestion(bool bRedCongestionOnThoracicAndSpiral)
{
	bCongestionHeatmap = bRedCongestionOnThoracicAndSpiral;
}

void UFELFascialSlingVisualizer::SetSpiralPulsePhase(float Phase01)
{
	PulsePhase = FMath::Clamp(Phase01, 0.f, 1.f);
	if (SpiralMID)
	{
		SpiralMID->SetScalarParameterValue(TEXT("PulsePhase"), PulsePhase);
		SpiralMID->SetScalarParameterValue(TEXT("Congestion"), bCongestionHeatmap ? 1.f : 0.f);
	}
}

void UFELFascialSlingVisualizer::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
	if (!bSlingActive)
	{
		return;
	}
	PulseAccum += DeltaTime * 1.2f;
	const float P = 0.5f + 0.5f * FMath::Sin(PulseAccum * 6.2831853f);
	SetSpiralPulsePhase(P);
}
