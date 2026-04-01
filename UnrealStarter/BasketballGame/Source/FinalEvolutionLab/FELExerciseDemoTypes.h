// Copyright (c) Final Evolution Lab.
// When "Perfect Form" / Bonds Bounce exercise demonstrations may run relative to match phase and basketball rule slice.

#pragma once

#include "CoreMinimal.h"
#include "FELExerciseDemoTypes.generated.h"

UENUM(BlueprintType)
enum class EFELExerciseDemoGameplayPolicy : uint8
{
	/** Only while waiting for countdown / start (legacy behaviour). */
	PreMatchOnly UMETA(DisplayName = "Pre-match / countdown only"),
	/** Pre-match plus active Practice sessions (open fitness / form review during play). */
	PracticeOpenPlay UMETA(DisplayName = "Practice mode + pre-match"),
	/** Any live phase except post-match results (use for lab / Pixel Streaming shells). */
	AnyExceptMatchComplete UMETA(DisplayName = "In play except match complete"),
};
