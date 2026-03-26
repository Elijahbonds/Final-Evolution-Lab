// Copyright (c) Final Evolution Lab.
// Resolves UFELCreatorCard from readiness (explicit asset path or stood card id → convention path).

#pragma once

#include "CoreMinimal.h"
#include "FELReadinessTypes.h"

class UFELCreatorCard;

struct FFELCreatorCardResolver
{
	/**
	 * Load stood Creator Card for Street / H2H / 3v3 (sync).
	 * 1) `StoodCreatorCardDataAssetPath` if set (e.g. `/Game/FEL/Data/Cards/MyCard.MyCard`)
	 * 2) Else `/Game/FEL/Data/CreatorCards/DA_{StoodCreatorCardId}.DA_{StoodCreatorCardId}` (spaces → _)
	 */
	static FINALEVOLUTIONLAB_API UFELCreatorCard* ResolveFromReadiness(const FFELReadinessSnapshot& Snap);
};
