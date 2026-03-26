// Copyright (c) Final Evolution Lab.

#include "UFELBiometricOverlays.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "Materials/MaterialInstanceDynamic.h"

void UFELBiometricOverlays::ApplyGlobalRhythmPulse(UObject* WorldContextObject, int32 BeatPhaseMod3)
{
	UWorld* World = GEngine ? GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::ReturnNull) : nullptr;
	if (!World)
	{
		return;
	}
	for (TActorIterator<AActor> It(World); It; ++It)
	{
		AActor* A = *It;
		if (UFELBiometricOverlays* O = A->FindComponentByClass<UFELBiometricOverlays>())
		{
			O->OnPushRhythmBeat(BeatPhaseMod3);
		}
	}
}

UFELBiometricOverlays::UFELBiometricOverlays()
{
	PrimaryComponentTick.bCanEverTick = true;
	PrimaryComponentTick.TickGroup = TG_PostUpdateWork;
}

void UFELBiometricOverlays::BeginPlay()
{
	Super::BeginPlay();
	SetComponentTickEnabled(bOverlaysActive);
	EnsureMIDs();
	ApplyCongestionVisual(bSFMA_RotationRoadblock);
}

void UFELBiometricOverlays::EnsureMIDs()
{
	if (SpiralLineMesh && SpiralLineMesh->GetNumMaterials() > 0 && !SpiralMID)
	{
		SpiralMID = SpiralLineMesh->CreateDynamicMaterialInstance(0);
	}
	if (FrontFunctionalLineMesh && FrontFunctionalLineMesh->GetNumMaterials() > 0 && !FrontMID)
	{
		FrontMID = FrontFunctionalLineMesh->CreateDynamicMaterialInstance(0);
	}
}

void UFELBiometricOverlays::SetClinicalOverlaysActive(bool bActive)
{
	bOverlaysActive = bActive;
	SetComponentTickEnabled(bActive);
	if (SpiralLineMesh)
	{
		SpiralLineMesh->SetVisibility(bActive);
	}
	if (FrontFunctionalLineMesh)
	{
		FrontFunctionalLineMesh->SetVisibility(bActive);
	}
}

void UFELBiometricOverlays::ApplyBiometricContext(const FFELBiometricContext& Context)
{
	bSFMA_RotationRoadblock = !Context.bSFMASpiralRotationScreenPass;
	ApplyCongestionVisual(bSFMA_RotationRoadblock);
}

void UFELBiometricOverlays::ApplyCongestionVisual(bool bRedRoadblock)
{
	const float C = bRedRoadblock ? 1.f : 0.f;
	if (SpiralMID)
	{
		SpiralMID->SetScalarParameterValue(TEXT("Congestion"), C);
		SpiralMID->SetVectorParameterValue(TEXT("RoadblockTint"), bRedRoadblock ? FLinearColor(0.95f, 0.12f, 0.08f, 1.f) : FLinearColor::Transparent);
	}
	if (FrontMID)
	{
		FrontMID->SetScalarParameterValue(TEXT("Congestion"), C);
		FrontMID->SetScalarParameterValue(TEXT("FrontFunctionalTension"), FrontFunctionalTension);
	}
}

void UFELBiometricOverlays::OnPushRhythmBeat(int32 BeatPhaseMod3)
{
	const int32 Phase = ((BeatPhaseMod3 % 3) + 3) % 3;
	PushPulseForPhase(Phase);
}

void UFELBiometricOverlays::PushPulseForPhase(int32 Phase)
{
	// Penultimate "Push" — emphasize spiral pulse; "1,2" — front line tension + sharper emissive snap.
	if (Phase == 0)
	{
		SpiralPulseBoost = 1.f;
		FrontFunctionalTension = FMath::Clamp(FrontFunctionalTension + 0.35f, 0.f, 1.f);
	}
	else
	{
		SpiralPulseBoost = 0.55f;
		FrontFunctionalTension = FMath::Clamp(0.2f + 0.4f * static_cast<float>(Phase), 0.f, 1.f);
	}
	ApplyCongestionVisual(bSFMA_RotationRoadblock);
}

void UFELBiometricOverlays::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
	if (!bOverlaysActive)
	{
		return;
	}
	PulseAccum += DeltaTime * BasePulseSpeed * (1.f + SpiralPulseBoost);
	const float P = 0.5f + 0.5f * FMath::Sin(PulseAccum * 6.2831853f);
	SpiralPulseBoost = FMath::FInterpTo(SpiralPulseBoost, 0.f, DeltaTime, 3.f);
	FrontFunctionalTension = FMath::FInterpTo(FrontFunctionalTension, bSFMA_RotationRoadblock ? 0.85f : 0.35f, DeltaTime, 2.f);

	const float SpiralPulse = P * (1.f + 0.35f * SpiralPulseBoost) * SpiralVisualIntensityScale;
	static constexpr float PulseEpsilon = 0.002f;
	if (SpiralMID && FMath::Abs(SpiralPulse - LastWrittenSpiralPulse) > PulseEpsilon)
	{
		LastWrittenSpiralPulse = SpiralPulse;
		SpiralMID->SetScalarParameterValue(TEXT("PulsePhase"), SpiralPulse);
	}
	if (FrontMID)
	{
		if (FMath::Abs(FrontFunctionalTension - LastWrittenFrontTension) > PulseEpsilon)
		{
			LastWrittenFrontTension = FrontFunctionalTension;
			FrontMID->SetScalarParameterValue(TEXT("FrontFunctionalTension"), FrontFunctionalTension);
		}
		if (FMath::Abs(P - LastWrittenFrontPulsePhase) > PulseEpsilon)
		{
			LastWrittenFrontPulsePhase = P;
			FrontMID->SetScalarParameterValue(TEXT("PulsePhase"), P);
		}
	}
}
