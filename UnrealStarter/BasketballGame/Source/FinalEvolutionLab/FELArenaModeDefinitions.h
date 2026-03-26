// Copyright (c) Final Evolution Lab.
// Arena modes — parity with Swift `GameModeId` / PROJECT_FLOWS.md (includes `market_browse` / Sovereign Shop).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.generated.h"

/** All operable Arena modes (Swift `GameModeId` / `GameMode.swift`). */
UENUM(BlueprintType)
enum class EFELArenaMode : uint8
{
	BasketballHeadToHead UMETA(DisplayName = "Head to Head"),
	BasketballDunkContest UMETA(DisplayName = "Dunk Contest (Arena / Lab parity)"),
	Basketball3v3 UMETA(DisplayName = "3v3 / 3-Point Shootout"),
	Karate UMETA(DisplayName = "Karate"),
	Baseball UMETA(DisplayName = "Baseball"),
	Football UMETA(DisplayName = "Football"),
	Soccer UMETA(DisplayName = "Soccer"),
	Golf UMETA(DisplayName = "Golf"),
	Tennis UMETA(DisplayName = "Tennis"),
	Volleyball UMETA(DisplayName = "Volleyball"),
	Gymnastics UMETA(DisplayName = "Gymnastics"),
	BrainBrawl UMETA(DisplayName = "Brain Brawl"),
	/** Sovereign Gear — Luma photogrammetry shop (`market_browse`). */
	MarketBrowse UMETA(DisplayName = "Sovereign Shop (market browse)"),
	Unknown UMETA(Hidden),
};

namespace FELArenaModeIds
{
	inline const TCHAR* BasketballHeadToHead = TEXT("basketball_h2h");
	inline const TCHAR* BasketballDunk = TEXT("basketball_dunk");
	inline const TCHAR* Basketball3v3 = TEXT("basketball_3v3");
	inline const TCHAR* Karate = TEXT("karate");
	inline const TCHAR* KarateHeadToHead = TEXT("karate_h2h");
	inline const TCHAR* KarateEndless = TEXT("karate_endless");
	inline const TCHAR* Baseball = TEXT("baseball");
	inline const TCHAR* Football = TEXT("football");
	inline const TCHAR* Soccer = TEXT("soccer");
	inline const TCHAR* Golf = TEXT("golf");
	inline const TCHAR* Tennis = TEXT("tennis");
	inline const TCHAR* Volleyball = TEXT("volleyball");
	inline const TCHAR* Gymnastics = TEXT("gymnastics");
	inline const TCHAR* BrainBrawl = TEXT("brain_brawl");
	inline const TCHAR* MarketBrowse = TEXT("market_browse");
}

FINALEVOLUTIONLAB_API EFELArenaMode FELArenaModeFromSwiftId(const FString& SwiftId);
FINALEVOLUTIONLAB_API FString FELArenaModeToSwiftId(EFELArenaMode Mode);
