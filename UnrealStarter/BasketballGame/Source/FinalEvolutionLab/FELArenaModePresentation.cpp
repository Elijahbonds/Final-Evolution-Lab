// Copyright (c) Final Evolution Lab.

#include "FELArenaModePresentation.h"

FString FELGetArenaModeInspirationTag(const EFELArenaMode Mode)
{
	switch (Mode)
	{
	case EFELArenaMode::BasketballHeadToHead:
	case EFELArenaMode::Basketball3v3:
		return TEXT("Street hoops · combo flow and rim finishes");
	case EFELArenaMode::BasketballDunkContest:
		return TEXT("Style chains · contest meter from made dunks");
	case EFELArenaMode::Karate:
		return TEXT("Dojo exchanges · timing windows and footwork");
	case EFELArenaMode::Baseball:
	case EFELArenaMode::Golf:
		return TEXT("Motion sports · swing timing and tempo");
	case EFELArenaMode::Football:
		return TEXT("Kick return · possession waves, stamina, and touchdown target");
	case EFELArenaMode::Soccer:
		return TEXT("Stadium pitch · possession and finishing");
	case EFELArenaMode::Tennis:
	case EFELArenaMode::Volleyball:
		return TEXT("Court sports · lateral movement and rally scoring");
	case EFELArenaMode::Gymnastics:
		return TEXT("Floor work · routine pacing and landings");
	case EFELArenaMode::BrainBrawl:
		return TEXT("Academy quiz · timed rounds and interest paths");
	case EFELArenaMode::MarketBrowse:
		return TEXT("Luma Venice — Sovereign Gear");
	default:
		return FString();
	}
}
