// Copyright (c) Final Evolution Lab.

#include "FELCreatorCardResolver.h"
#include "UFELCreatorCard.h"
#include "UObject/SoftObjectPath.h"
#include "UObject/UObjectGlobals.h"

UFELCreatorCard* FFELCreatorCardResolver::ResolveFromReadiness(const FFELReadinessSnapshot& Snap)
{
	const FString Explicit = Snap.StoodCreatorCardDataAssetPath.TrimStartAndEnd();
	if (!Explicit.IsEmpty())
	{
		FSoftObjectPath P(Explicit);
		if (UObject* O = P.TryLoad())
		{
			return Cast<UFELCreatorCard>(O);
		}
	}

	FString Id = Snap.StoodCreatorCardId.TrimStartAndEnd();
	if (Id.IsEmpty())
	{
		return nullptr;
	}
	Id.ReplaceInline(TEXT(" "), TEXT("_"));
	Id.ReplaceInline(TEXT("-"), TEXT("_"));

	const FString Path = FString::Printf(TEXT("/Game/FEL/Data/CreatorCards/DA_%s.DA_%s"), *Id, *Id);
	if (UObject* O = StaticLoadObject(UFELCreatorCard::StaticClass(), nullptr, *Path, nullptr, LOAD_None, nullptr))
	{
		return Cast<UFELCreatorCard>(O);
	}
	return nullptr;
}
