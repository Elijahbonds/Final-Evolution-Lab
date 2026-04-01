// Copyright (c) Final Evolution Lab.

#include "FELArenaVenueTravel.h"
#include "FELArenaRulesRegistry.h"
#include "FELDigitalTwinVenuePaths.h"
#include "UObject/SoftObjectPath.h"

namespace
{
	FString FelInferVenueTokenFromPackage(const FString& Pkg)
	{
		FString Clean = Pkg.TrimStartAndEnd();
		int32 Dot = INDEX_NONE;
		if (Clean.FindLastChar(TEXT('.'), Dot))
		{
			Clean = Clean.Left(Dot);
		}
		int32 Slash = INDEX_NONE;
		if (Clean.FindLastChar(TEXT('/'), Slash))
		{
			return Clean.Mid(Slash + 1);
		}
		return Clean;
	}
}

bool FELArenaVenueTravel::ResolveOpenLevelName(const EFELArenaMode Mode, FName& OutLevelPackageName)
{
	const FFELArenaRules Rules = FELArenaRulesRegistry::GetMergedRules(Mode);
	if (!Rules.UnrealOpenLevelPackage.IsEmpty())
	{
		OutLevelPackageName = FName(*Rules.UnrealOpenLevelPackage);
		return true;
	}

	switch (Mode)
	{
	case EFELArenaMode::BasketballHeadToHead:
	case EFELArenaMode::BasketballDunkContest:
	case EFELArenaMode::Basketball3v3:
		OutLevelPackageName = FName(FELDigitalTwinVenuePaths::VeniceBeachArena);
		return true;
	case EFELArenaMode::Karate:
		OutLevelPackageName = FName(FELDigitalTwinVenuePaths::DojoStadium);
		return true;
	case EFELArenaMode::Soccer:
		OutLevelPackageName = FName(FELDigitalTwinVenuePaths::SoccerStadium);
		return true;
	case EFELArenaMode::Baseball:
		OutLevelPackageName = FName(FELArenaVenueLevelPaths::BaseballPark);
		return true;
	case EFELArenaMode::Football:
		OutLevelPackageName = FName(FELArenaVenueLevelPaths::Gridiron);
		return true;
	case EFELArenaMode::Golf:
		OutLevelPackageName = FName(FELArenaVenueLevelPaths::GolfLinks);
		return true;
	case EFELArenaMode::Tennis:
		OutLevelPackageName = FName(FELArenaVenueLevelPaths::TennisCourt);
		return true;
	case EFELArenaMode::Volleyball:
		OutLevelPackageName = FName(FELArenaVenueLevelPaths::SandCourt);
		return true;
	case EFELArenaMode::Gymnastics:
		OutLevelPackageName = FName(FELArenaVenueLevelPaths::TrainingFloor);
		return true;
	case EFELArenaMode::BrainBrawl:
		OutLevelPackageName = FName(FELArenaVenueLevelPaths::NeuroArena);
		return true;
	case EFELArenaMode::MarketBrowse:
		OutLevelPackageName = FName(FELDigitalTwinVenuePaths::LumaVeniceShop);
		return true;
	case EFELArenaMode::Unknown:
	default:
		return false;
	}
}

FSoftObjectPath FELArenaVenueTravel::GetDefaultVenueSoftPath(const EFELArenaMode Mode)
{
	FName N;
	if (ResolveOpenLevelName(Mode, N))
	{
		return FSoftObjectPath(N.ToString());
	}
	return FSoftObjectPath(FELDigitalTwinVenuePaths::VeniceBeachArena);
}

bool FELArenaVenueTravel::ShouldSkipTravelBecauseAlreadyOnVenue(const EFELArenaMode Mode, const FString& Current)
{
	const FFELArenaRules Rules = FELArenaRulesRegistry::GetMergedRules(Mode);
	if (!Rules.UnrealOpenLevelPackage.IsEmpty())
	{
		const FString Token = Rules.UnrealVenuePresenceToken.IsEmpty()
			                          ? FelInferVenueTokenFromPackage(Rules.UnrealOpenLevelPackage)
			                          : Rules.UnrealVenuePresenceToken;
		return !Token.IsEmpty() && Current.Contains(Token);
	}

	switch (Mode)
	{
	case EFELArenaMode::BasketballHeadToHead:
	case EFELArenaMode::BasketballDunkContest:
	case EFELArenaMode::Basketball3v3:
		return Current.Contains(TEXT("VeniceBeach")) || Current.Contains(TEXT("VeniceBeach_Arena")) || Current.Contains(TEXT("VeniceLuma"))
			|| Current.Contains(TEXT("L_VeniceLuma"));
	case EFELArenaMode::Karate:
		return Current.Contains(TEXT("Dojo_Stadium")) || Current.Contains(TEXT("Dojo"));
	case EFELArenaMode::Soccer:
		return Current.Contains(TEXT("SoccerStadium")) || Current.Contains(TEXT("Pitch"));
	case EFELArenaMode::Baseball:
		return Current.Contains(TEXT("BaseballPark"));
	case EFELArenaMode::Football:
		return Current.Contains(TEXT("Gridiron"));
	case EFELArenaMode::Golf:
		return Current.Contains(TEXT("Links"));
	case EFELArenaMode::Tennis:
		return Current.Contains(TEXT("TennisCourt"));
	case EFELArenaMode::Volleyball:
		return Current.Contains(TEXT("SandCourt"));
	case EFELArenaMode::Gymnastics:
		return Current.Contains(TEXT("TrainingFloor"));
	case EFELArenaMode::BrainBrawl:
		return Current.Contains(TEXT("NeuroArena"));
	case EFELArenaMode::MarketBrowse:
		return Current.Contains(TEXT("SovereignShop")) || Current.Contains(TEXT("L_SovereignShop_Luma")) || Current.Contains(TEXT("Luma_Venice_Shop"));
	default:
		return false;
	}
}

FString FELArenaVenueTravel::GetVenueMatrixLabel(const EFELArenaMode Mode)
{
	switch (Mode)
	{
	case EFELArenaMode::BasketballHeadToHead:
	case EFELArenaMode::BasketballDunkContest:
	case EFELArenaMode::Basketball3v3:
		return TEXT("VeniceBeach (basketball H2H / dunk / 3v3)");
	case EFELArenaMode::Karate:
		return TEXT("Dojo");
	case EFELArenaMode::Soccer:
		return TEXT("SoccerStadium");
	case EFELArenaMode::Baseball:
		return TEXT("BaseballPark");
	case EFELArenaMode::Football:
		return TEXT("Gridiron");
	case EFELArenaMode::Golf:
		return TEXT("Links");
	case EFELArenaMode::Tennis:
		return TEXT("TennisCourt");
	case EFELArenaMode::Volleyball:
		return TEXT("SandCourt");
	case EFELArenaMode::Gymnastics:
		return TEXT("TrainingFloor");
	case EFELArenaMode::BrainBrawl:
		return TEXT("NeuroArena");
	case EFELArenaMode::MarketBrowse:
		return TEXT("LumaVeniceShop");
	default:
		return TEXT("(no venue travel)");
	}
}
