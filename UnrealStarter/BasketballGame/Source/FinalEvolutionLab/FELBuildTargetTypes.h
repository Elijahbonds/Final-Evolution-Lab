// Copyright (c) Final Evolution Lab.
// Universal Launch — unified build tier for PS5, iOS, Android, Pixel Streaming (Web), and desktop.

#pragma once

#include "CoreMinimal.h"
#include "FELBuildTargetTypes.generated.h"

/** Active shipping tier — use `FELPlatformManager::GetActivePlatform()` (see FELPlatformManager.h). */
UENUM(BlueprintType)
enum class EFELBuildTarget : uint8
{
	Unknown UMETA(DisplayName = "Unknown"),
	IOS UMETA(DisplayName = "iOS"),
	Android UMETA(DisplayName = "Android"),
	PS5 UMETA(DisplayName = "PS5"),
	MacDesktop UMETA(DisplayName = "MacDesktop"),
	Win64 UMETA(DisplayName = "Win64"),
	Linux UMETA(DisplayName = "Linux"),
	/** Web / Pixel Streaming sender or client build — enable with PIXEL_STREAMING_ENABLED=1 + Pixel Streaming plugin. */
	PixelStreaming UMETA(DisplayName = "PixelStreaming"),
};
