// Copyright (c) Final Evolution Lab.
// Place in level to receive biometric scalars (materials, wind, post — Blueprint or subclass).

#pragma once

#include "CoreMinimal.h"
#include "IFELBiometricReceiver.h"
#include "GameFramework/Actor.h"
#include "FELBiometricEnvironmentActor.generated.h"

class UFELBiometricOverlays;

UCLASS()
class FINALEVOLUTIONLAB_API AFELBiometricEnvironmentActor : public AActor, public IFELBiometricReceiver
{
	GENERATED_BODY()

public:
	AFELBiometricEnvironmentActor();

	/** 0.85–1.12 typical; drive floor friction / PP from Blueprint. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Biometric")
	float GlobalFrictionScale = 1.f;

	/** Spiral Line + Front Functional Line clinical HUD (assign meshes on component in-editor). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Clinical")
	TObjectPtr<UFELBiometricOverlays> ClinicalOverlays = nullptr;

	virtual void ApplyBiometricContext_Implementation(const FFELBiometricContext& Context) override;

protected:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	USceneComponent* RootScene = nullptr;
};
