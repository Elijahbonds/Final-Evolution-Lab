// Copyright (c) Final Evolution Lab.
// Unreal basketball prototype rule slices (maps from 12 Swift Arena modes where applicable).

#pragma once

#include "CoreMinimal.h"
#include "FELBasketballModes.generated.h"

UENUM(BlueprintType)
enum class EFELBasketballPlayMode : uint8
{
	StreetBall UMETA(DisplayName = "Street Ball"),
	HalfCourtShootout UMETA(DisplayName = "Half-Court Shootout"),
	TimedBlitz UMETA(DisplayName = "Timed Blitz"),
	Practice UMETA(DisplayName = "Practice"),
	FirstToTwentyOne UMETA(DisplayName = "First to 21"),
};
