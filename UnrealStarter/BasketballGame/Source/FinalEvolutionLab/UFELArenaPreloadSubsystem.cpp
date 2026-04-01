// Copyright (c) Final Evolution Lab.

#include "UFELArenaPreloadSubsystem.h"
#include "FELArenaModeCatalog.h"
#include "FELArenaModeDefinitions.h"

void UFELArenaPreloadSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);

	static const EFELArenaMode kOrder[] = {
		EFELArenaMode::BasketballHeadToHead,
		EFELArenaMode::BasketballDunkContest,
		EFELArenaMode::Basketball3v3,
		EFELArenaMode::Karate,
		EFELArenaMode::Baseball,
		EFELArenaMode::Football,
		EFELArenaMode::Soccer,
		EFELArenaMode::Golf,
		EFELArenaMode::Tennis,
		EFELArenaMode::Volleyball,
		EFELArenaMode::Gymnastics,
		EFELArenaMode::BrainBrawl,
		EFELArenaMode::MarketBrowse,
		EFELArenaMode::Surfing,
		EFELArenaMode::Skateboarding,
		EFELArenaMode::Snowboarding,
	};

	TArray<FSoftObjectPath> Paths;
	for (EFELArenaMode M : kOrder)
	{
		Paths.Add(FELArenaModeCatalog::GetDefaultSoftPathForMode(M));
	}

	ArenaPreloadHandle = StreamableManager.RequestAsyncLoad(
		Paths,
		FStreamableDelegate::CreateUObject(this, &UFELArenaPreloadSubsystem::OnArenaModesPreloaded));
}

void UFELArenaPreloadSubsystem::OnArenaModesPreloaded()
{
	bArenaPreloadFinished = true;
	ArenaPreloadHandle.Reset();
}
