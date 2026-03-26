// Copyright (c) Final Evolution Lab.
// Buffered action ids for UFELInputComponent (Bonds Bounce input pipeline).

#pragma once

#include "CoreMinimal.h"
#include "FELInputBufferTypes.generated.h"

UENUM(BlueprintType)
enum class EFELBufferedActionType : uint8
{
	None UMETA(Hidden),
	Jump UMETA(DisplayName = "Jump / Dunk takeoff"),
	Kick UMETA(DisplayName = "Kick / Strike"),
	Interact UMETA(DisplayName = "Interact / Pickup"),
};
