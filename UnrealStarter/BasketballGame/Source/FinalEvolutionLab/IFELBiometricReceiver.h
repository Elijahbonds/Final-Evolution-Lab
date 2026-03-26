// Copyright (c) Final Evolution Lab.
// Interface: Neural Drive + Kinetic Leakage affect the entire Arena (not only the pawn).

#pragma once

#include "CoreMinimal.h"
#include "FELBiometricTypes.h"
#include "UObject/Interface.h"
#include "IFELBiometricReceiver.generated.h"

UINTERFACE(MinimalApi, Blueprintable)
class UFELBiometricReceiver : public UInterface
{
	GENERATED_BODY()
};

class IFELBiometricReceiver
{
	GENERATED_IINTERFACE_BODY()

public:
	/** Apply Bonds Bounce / readiness-derived tuning (call after bridge or mode load). */
	UFUNCTION(BlueprintNativeEvent, Category = "FEL|Biometric")
	void ApplyBiometricContext(const FFELBiometricContext& Context);
};
