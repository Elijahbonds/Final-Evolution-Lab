// Copyright (c) Final Evolution Lab.
// Factory: merge Swift `GameModeId` defaults with Content/FEL/Config/ArenaSettings.json (no rules hard-coded in GameMode).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaRulesTypes.h"
#include "FELGameModeDefinitions.h"

/** Loads optional JSON overrides once; defaults are the factory fallback when a file or key is missing. */
struct FELArenaRulesRegistry
{
	static FFELArenaRules GetMergedRules(EFELArenaMode Mode);

	/** Hotfix layer on top of UFELArenaModeData or factory defaults (Content/FEL/Config/ArenaSettings.json). */
	static void ApplyJsonOverridesToRules(EFELArenaMode Mode, FFELArenaRules& InOut);

	/** Numeric clamps + sport neuro bounds (shared by GetMergedRules and Data Asset path). */
	static void SanitizeRulesInPlace(FFELArenaRules& R, EFELArenaMode Mode);
};
