// Copyright (c) Final Evolution Lab.
// Jump timing bands for Neuro-Reactive movement (Bonds Bounce Blueprint — input timing vs ideal gather window).

#pragma once

#include "CoreMinimal.h"
#include "FELJumpTimingTypes.generated.h"

UENUM(BlueprintType)
enum class EFELJumpTimingBand : uint8
{
	None UMETA(DisplayName = "None"),
	Early UMETA(DisplayName = "Leaky Early"),
	Good UMETA(DisplayName = "Good"),
	Perfect UMETA(DisplayName = "Perfect"),
	Late UMETA(DisplayName = "Leaky Late")
};
