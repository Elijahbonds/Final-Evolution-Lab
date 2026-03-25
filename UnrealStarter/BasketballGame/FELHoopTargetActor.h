// Copyright (c) Final Evolution Lab.
// Place at rim / goal; ball predictive magnet uses this interface location.

#pragma once

#include "CoreMinimal.h"
#include "Components/SceneComponent.h"
#include "IFELInteractable.h"
#include "GameFramework/Actor.h"
#include "FELHoopTargetActor.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API AFELHoopTargetActor : public AActor, public IFELInteractable
{
	GENERATED_BODY()

public:
	AFELHoopTargetActor();

	virtual FVector GetMagnetTargetLocation_Implementation() const override;
	virtual float GetPredictiveMagnetStrength_Implementation(float NeuralDrive0to100) const override;

protected:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Interact")
	USceneComponent* RootScene = nullptr;

	/** Scales assist at Neural Drive 90+ (0.12 @ 100). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Interact", meta = (ClampMin = "0", ClampMax = "0.5"))
	float EliteMagnetStrengthMax = 0.12f;
};
