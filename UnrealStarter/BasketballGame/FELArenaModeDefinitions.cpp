// Copyright (c) Final Evolution Lab.

#include "FELArenaModeDefinitions.h"

EFELArenaMode FELArenaModeFromSwiftId(const FString& SwiftId)
{
	const FString Id = SwiftId.TrimStartAndEnd().ToLower();
	if (Id == FELArenaModeIds::BasketballHeadToHead)
	{
		return EFELArenaMode::BasketballHeadToHead;
	}
	if (Id == FELArenaModeIds::BasketballDunk || Id == TEXT("dunk_contest") || Id == TEXT("dunkcontest"))
	{
		return EFELArenaMode::BasketballDunkContest;
	}
	if (Id == FELArenaModeIds::Basketball3v3)
	{
		return EFELArenaMode::Basketball3v3;
	}
	if (Id == FELArenaModeIds::Karate)
	{
		return EFELArenaMode::Karate;
	}
	if (Id == FELArenaModeIds::Baseball)
	{
		return EFELArenaMode::Baseball;
	}
	if (Id == FELArenaModeIds::Football)
	{
		return EFELArenaMode::Football;
	}
	if (Id == FELArenaModeIds::Soccer)
	{
		return EFELArenaMode::Soccer;
	}
	if (Id == FELArenaModeIds::Golf)
	{
		return EFELArenaMode::Golf;
	}
	if (Id == FELArenaModeIds::Tennis)
	{
		return EFELArenaMode::Tennis;
	}
	if (Id == FELArenaModeIds::Volleyball)
	{
		return EFELArenaMode::Volleyball;
	}
	if (Id == FELArenaModeIds::Gymnastics)
	{
		return EFELArenaMode::Gymnastics;
	}
	if (Id == FELArenaModeIds::BrainBrawl)
	{
		return EFELArenaMode::BrainBrawl;
	}
	if (Id == FELArenaModeIds::MarketBrowse || Id == TEXT("sovereign_shop"))
	{
		return EFELArenaMode::MarketBrowse;
	}
	return EFELArenaMode::Unknown;
}

FString FELArenaModeToSwiftId(EFELArenaMode Mode)
{
	switch (Mode)
	{
	case EFELArenaMode::BasketballHeadToHead:
		return FELArenaModeIds::BasketballHeadToHead;
	case EFELArenaMode::BasketballDunkContest:
		return FELArenaModeIds::BasketballDunk;
	case EFELArenaMode::Basketball3v3:
		return FELArenaModeIds::Basketball3v3;
	case EFELArenaMode::Karate:
		return FELArenaModeIds::Karate;
	case EFELArenaMode::Baseball:
		return FELArenaModeIds::Baseball;
	case EFELArenaMode::Football:
		return FELArenaModeIds::Football;
	case EFELArenaMode::Soccer:
		return FELArenaModeIds::Soccer;
	case EFELArenaMode::Golf:
		return FELArenaModeIds::Golf;
	case EFELArenaMode::Tennis:
		return FELArenaModeIds::Tennis;
	case EFELArenaMode::Volleyball:
		return FELArenaModeIds::Volleyball;
	case EFELArenaMode::Gymnastics:
		return FELArenaModeIds::Gymnastics;
	case EFELArenaMode::BrainBrawl:
		return FELArenaModeIds::BrainBrawl;
	case EFELArenaMode::MarketBrowse:
		return FELArenaModeIds::MarketBrowse;
	default:
		return FELArenaModeIds::BasketballHeadToHead;
	}
}
