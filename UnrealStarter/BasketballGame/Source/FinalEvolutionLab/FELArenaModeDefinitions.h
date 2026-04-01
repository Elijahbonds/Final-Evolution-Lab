// Copyright (c) Final Evolution Lab.
// Canonical Unreal arena modes — string ids in `FELArenaModeIds` match `readiness_snapshot.json` active_mode + ArenaSettings.json keys (includes `market_browse` / Sovereign Shop).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.generated.h"

/**
 * All operable arena experiences shipped from Unreal (twelve sports/lab modes + Sovereign Shop browse).
 * Use FELArenaModeToIdString / FELArenaModeFromIdString for JSON and config.
 */
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

/** Parse canonical mode id string (e.g. basketball_h2h, brain_brawl) from JSON / profile. */
FINALEVOLUTIONLAB_API EFELArenaMode FELArenaModeFromIdString(const FString& IdString);
/** Serialize enum to canonical id for ArenaSettings.json, session export, and readiness snapshot. */
FINALEVOLUTIONLAB_API FString FELArenaModeToIdString(EFELArenaMode Mode);
