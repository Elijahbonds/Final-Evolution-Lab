// Copyright (c) Final Evolution Lab.
// Single source for arena mode → OpenLevel package name + "already on venue" heuristics (Phase 5 venue matrix).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "UObject/SoftObjectPath.h"

namespace FELArenaVenueTravel
{
	/** @return false for Unknown / unmapped — no OpenLevel. */
	FINALEVOLUTIONLAB_API bool ResolveOpenLevelName(EFELArenaMode Mode, FName& OutLevelPackageName);

	/** Soft path for UFELAssetRegistrySubsystem warm-up (must match ResolveOpenLevelName). */
	FINALEVOLUTIONLAB_API FSoftObjectPath GetDefaultVenueSoftPath(EFELArenaMode Mode);

	/**
	 * Heuristic: short level name from GetCurrentLevelName(World, true) vs expected venue token.
	 * Avoids redundant OpenLevel when snapshot re-applies on the correct map.
	 */
	FINALEVOLUTIONLAB_API bool ShouldSkipTravelBecauseAlreadyOnVenue(EFELArenaMode Mode, const FString& CurrentLevelShortName);

	/** Clinical label for logs / HUD (not localized). */
	FINALEVOLUTIONLAB_API FString GetVenueMatrixLabel(EFELArenaMode Mode);
}
