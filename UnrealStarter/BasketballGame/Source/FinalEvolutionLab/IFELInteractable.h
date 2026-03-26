// Copyright (c) Final Evolution Lab.
// Rim / hoop / strike targets — Neural Drive can bias ball flight (predictive assist).

#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "IFELInteractable.generated.h"

UINTERFACE(MinimalApi, Blueprintable)
class UFELInteractable : public UInterface
{
	GENERATED_BODY()
};

class IFELInteractable
{
	GENERATED_IINTERFACE_BODY()

public:
	/** World location used for elite "magnet" assist (hoop / goal / mitts). */
	UFUNCTION(BlueprintNativeEvent, Category = "FEL|Interact")
	FVector GetMagnetTargetLocation() const;

	/** 0 = no assist; at high Neural Drive (e.g. 90+) return larger values (tuned in BP). */
	UFUNCTION(BlueprintNativeEvent, Category = "FEL|Interact")
	float GetPredictiveMagnetStrength(float NeuralDrive0to100) const;
};
