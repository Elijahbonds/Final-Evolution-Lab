// Copyright (c) Final Evolution Lab.

#include "FELArenaModeCatalog.h"

FSoftObjectPath FELArenaModeCatalog::GetDefaultSoftPathForMode(const EFELArenaMode Mode)
{
	switch (Mode)
	{
	case EFELArenaMode::BasketballHeadToHead:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_BasketballH2H.DA_ArenaMode_BasketballH2H"));
	case EFELArenaMode::BasketballDunkContest:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_BasketballDunk.DA_ArenaMode_BasketballDunk"));
	case EFELArenaMode::Basketball3v3:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_Basketball3v3.DA_ArenaMode_Basketball3v3"));
	case EFELArenaMode::Karate:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_Karate.DA_ArenaMode_Karate"));
	case EFELArenaMode::Baseball:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_Baseball.DA_ArenaMode_Baseball"));
	case EFELArenaMode::Football:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_Football.DA_ArenaMode_Football"));
	case EFELArenaMode::Soccer:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_Soccer.DA_ArenaMode_Soccer"));
	case EFELArenaMode::Golf:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_Golf.DA_ArenaMode_Golf"));
	case EFELArenaMode::Tennis:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_Tennis.DA_ArenaMode_Tennis"));
	case EFELArenaMode::Volleyball:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_Volleyball.DA_ArenaMode_Volleyball"));
	case EFELArenaMode::Gymnastics:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_Gymnastics.DA_ArenaMode_Gymnastics"));
	case EFELArenaMode::BrainBrawl:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_BrainBrawl.DA_ArenaMode_BrainBrawl"));
	case EFELArenaMode::MarketBrowse:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_BasketballH2H.DA_ArenaMode_BasketballH2H"));
	default:
		return FSoftObjectPath(TEXT("/Game/FEL/Data/DA_ArenaMode_BasketballH2H.DA_ArenaMode_BasketballH2H"));
	}
}
