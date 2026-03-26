// Copyright (c) Final Evolution Lab.
// Soft references for full-3D Lab / Arena venues — replace with shipped map paths after Meshy / art import.

#pragma once

#include "CoreMinimal.h"

namespace FELDigitalTwinVenuePaths
{
	/**
	 * Venice Beach arena — Luma scan shell for **Street 1v1, dunk contest, and 3v3** (same map; rules differ in GameState).
	 * Must match the cooked level (e.g. `VeniceBeach.umap` → `.../VeniceBeach.VeniceBeach`).
	 * Capture ref: `FELLumaCaptureIds::VeniceBeachCourt` — import mesh/splat into `/Game/FEL/Environment/` and build this level.
	 * Legacy: `/Game/FEL/Maps/VeniceBeach_Arena` or `L_VeniceLuma_Main` — change this constant + `MapsToCook` to match your .umap.
	 */
	inline const TCHAR* VeniceBeachArena = TEXT("/Game/FEL/Venues/VeniceBeach/VeniceBeach.VeniceBeach");

	/** Same as `VeniceBeachArena` — kept for call sites that referenced a separate Venues path. */
	inline const TCHAR* VeniceBeachArenaVenues = TEXT("/Game/FEL/Venues/VeniceBeach/VeniceBeach.VeniceBeach");

	/**
	 * Dojo / Karate — dedicated interior or Luma backplate; must match cooked `Dojo.umap`.
	 * Art: tatami, shoji, soft key light rig; place under `/Game/FEL/Environment/Dojo/` and reference from this level.
	 */
	inline const TCHAR* DojoStadium = TEXT("/Game/FEL/Venues/Dojo/Dojo.Dojo");

	/**
	 * Soccer — Meshy stadium shell + pitch (import `Meshy_AI_Stadium_Soccer_stad_*` into `/Game/FEL/Environment/Soccer/`, then save this map).
	 * See `EditorPython/fel_quick_soccer_stadium_level.py` for a minimal floor + PlayerStart if the art map is not ready yet.
	 */
	inline const TCHAR* SoccerStadium = TEXT("/Game/FEL/Venues/SoccerStadium/SoccerStadium.SoccerStadium");

	/**
	 * Sovereign Gear — dedicated sub-level for Luma capture (Gaussian Splat or imported mesh).
	 * See `FELLumaCaptureIds` for Venice Beach / Muscle Beach Luma UUIDs and links.
	 * Export from Luma app, then import splat/mesh via plugin or OBJ/GLB.
	 */
	inline const TCHAR* SovereignShopLuma = TEXT("/Game/FEL/Maps/L_SovereignShop_Luma.L_SovereignShop_Luma");

	/** Luma AI Venice Shop — `market_browse` / Shard marketplace (`FELLumaCaptureIds::LumaVeniceShop`). */
	inline const TCHAR* LumaVeniceShop = TEXT("/Game/FEL/Venues/Luma_Venice_Shop.Luma_Venice_Shop");

	/** Streamed chunk inside Venice (optional): shop anchor near boardwalk; keep sub-level path for `OpenLevel` isolation. */
	inline const TCHAR* VeniceBeachSovereignShopSub = TEXT("/Game/FEL/Maps/VeniceBeach_Arena_ShopSub.VeniceBeach_Arena_ShopSub");
}

/**
 * Arena venue maps for `OpenLevel` / `UFELAssetRegistrySubsystem` (must match cooked .umap names).
 */
namespace FELArenaVenueLevelPaths
{
	inline const TCHAR* BaseballPark = TEXT("/Game/FEL/Venues/BaseballPark/BaseballPark.BaseballPark");
	inline const TCHAR* Gridiron = TEXT("/Game/FEL/Venues/Gridiron/Gridiron.Gridiron");
	inline const TCHAR* GolfLinks = TEXT("/Game/FEL/Venues/Links/Links.Links");
	inline const TCHAR* TennisCourt = TEXT("/Game/FEL/Venues/TennisCourt/TennisCourt.TennisCourt");
	inline const TCHAR* SandCourt = TEXT("/Game/FEL/Venues/SandCourt/SandCourt.SandCourt");
	inline const TCHAR* TrainingFloor = TEXT("/Game/FEL/Venues/TrainingFloor/TrainingFloor.TrainingFloor");
	inline const TCHAR* NeuroArena = TEXT("/Game/FEL/Venues/NeuroArena/NeuroArena.NeuroArena");
}

/** Luma web capture UUIDs — assign per `AFELShopInteractionActor::LumaCaptureId` or analytics. */
namespace FELLumaCaptureIds
{
	/** [Venice Beach Court](https://lumalabs.ai/capture/853B6BC9-9E36-4AA1-B057-F47F433F3FD1) */
	inline const TCHAR* VeniceBeachCourt = TEXT("853B6BC9-9E36-4AA1-B057-F47F433F3FD1");

	/** [Muscle beach gym](https://lumalabs.ai/capture/A55022E1-C207-4FD5-8009-06F0D7E070B0) */
	inline const TCHAR* MuscleBeachGym = TEXT("A55022E1-C207-4FD5-8009-06F0D7E070B0");

	/** [Venice beach tennis courts](https://lumalabs.ai/capture/67214129-ED12-45C7-8F48-2B5CBEB9536E) */
	inline const TCHAR* VeniceBeachTennisCourts = TEXT("67214129-ED12-45C7-8F48-2B5CBEB9536E");

	/** [Venice Beach Black Top](https://lumalabs.ai/capture/3F15F2F3-2548-49CD-99FE-B2CB170C97B9) */
	inline const TCHAR* VeniceBeachBlackTop = TEXT("3F15F2F3-2548-49CD-99FE-B2CB170C97B9");

	/** Luma AI Venice Shop — primary capture for `FELDigitalTwinVenuePaths::LumaVeniceShop` / `market_browse`. */
	inline const TCHAR* LumaVeniceShop = TEXT("03953AA0-E30A-4680-AB5D-1889CC99F71D");
}
