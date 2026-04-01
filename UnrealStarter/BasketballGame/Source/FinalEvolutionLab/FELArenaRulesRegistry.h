// Copyright (c) Final Evolution Lab.
// Factory: merge canonical mode-id defaults with Content/FEL/Config/ArenaSettings.json (no rules hard-coded in GameMode).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaRulesTypes.h"
#include "FELGameModeDefinitions.h"

/** Loads optional JSON overrides once; defaults are the factory fallback when a file or key is missing. */
struct FELArenaRulesRegistry
{
	/**
	 * Merge factory defaults with `modes` in ArenaSettings.json.
	 * @param JsonModeKeyOverride When set (e.g. readiness `active_mode` = karate_h2h), selects that JSON row when multiple keys map to the same EFELArenaMode.
	 */
	static FFELArenaRules GetMergedRules(EFELArenaMode Mode, const FString& JsonModeKeyOverride = FString());

	/** Hotfix layer on top of UFELArenaModeData or factory defaults (Content/FEL/Config/ArenaSettings.json). */
	static void ApplyJsonOverridesToRules(EFELArenaMode Mode, FFELArenaRules& InOut, const FString& JsonModeKeyOverride = FString());

	/** Numeric clamps + sport neuro bounds (shared by GetMergedRules and Data Asset path). */
	static void SanitizeRulesInPlace(FFELArenaRules& R, EFELArenaMode Mode);
};
