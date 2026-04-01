// Copyright (c) Final Evolution Lab.
// Arena mode → OpenLevel package: `Content/FEL/Config/ArenaSettings.json` key `unrealOpenLevelPackage` per mode (see FFELArenaRules),
// then built-in fallbacks in `ResolveOpenLevelName` if the JSON field is empty.

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
