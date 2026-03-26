// Copyright (c) Final Evolution Lab.
// Launch-facing HUD copy: objective subtitles, score vocabulary, control hints per EFELArenaMode.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"

namespace FELArenaModeUX
{
	/** One-line goal / loop description under the mode title. */
	FINALEVOLUTIONLAB_API FString GetObjectiveSubtitle(EFELArenaMode Mode);

	/** Label for numeric score (e.g. Buckets vs Points vs Runs). */
	FINALEVOLUTIONLAB_API FString GetScoreTerm(EFELArenaMode Mode);

	/** Footer hint when match is active (movement / mode-specific). */
	FINALEVOLUTIONLAB_API FString GetControlFooterHint(EFELArenaMode Mode);
}
