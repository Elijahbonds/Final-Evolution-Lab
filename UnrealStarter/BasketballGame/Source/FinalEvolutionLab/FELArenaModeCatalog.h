// Copyright (c) Final Evolution Lab.
// Default soft paths for the 12 UFELArenaModeData assets (override per-ship in GameMode if needed).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"

struct FELArenaModeCatalog
{
	/** Content path for async/streaming load (Primary Data Asset). */
	static FINALEVOLUTIONLAB_API FSoftObjectPath GetDefaultSoftPathForMode(EFELArenaMode Mode);
};
