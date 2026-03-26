// Copyright (c) Final Evolution Lab.
// Optional AnimBP interface — wire PRQ + leakage into Layered Blend / Aim Offsets (Fatigued vs Primed).

#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "FELNeuroAnimLayerInterface.generated.h"

UINTERFACE(MinimalApi, Blueprintable)
class UFELNeuroAnimLayerInterface : public UInterface
{
	GENERATED_BODY()
};

class IFELNeuroAnimLayerInterface
{
	GENERATED_IINTERFACE_BODY()

public:
	/** Drive "Primed" vs "Fatigued" layers + hip extension scale from System Scan + PRQ. */
	UFUNCTION(BlueprintNativeEvent, Category = "FEL|Animation|Neuro")
	void FEL_ApplyNeuroLayerBlend(float PRQScore0to100, float PrimedLayerAlpha, float HipExtensionScale);
};
