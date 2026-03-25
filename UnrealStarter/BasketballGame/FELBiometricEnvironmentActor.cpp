// Copyright (c) Final Evolution Lab.

#include "FELBiometricEnvironmentActor.h"
#include "FELBiometricTypes.h"
#include "UFELBiometricOverlays.h"
#include "Components/SceneComponent.h"

AFELBiometricEnvironmentActor::AFELBiometricEnvironmentActor()
{
	PrimaryActorTick.bCanEverTick = false;
	RootScene = CreateDefaultSubobject<USceneComponent>(TEXT("RootScene"));
	SetRootComponent(RootScene);
	ClinicalOverlays = CreateDefaultSubobject<UFELBiometricOverlays>(TEXT("ClinicalOverlays"));
}

void AFELBiometricEnvironmentActor::ApplyBiometricContext_Implementation(const FFELBiometricContext& Context)
{
	const float Leak = static_cast<float>(FMath::Clamp(Context.KineticLeakageMultiplier, 0.45, 1.0));
	GlobalFrictionScale = FMath::Lerp(0.88f, 1.1f, Leak);
	if (ClinicalOverlays)
	{
		ClinicalOverlays->ApplyBiometricContext(Context);
	}
}
