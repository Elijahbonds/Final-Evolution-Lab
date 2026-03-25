// Copyright (c) Final Evolution Lab.
// Soft references for full-3D Lab / Arena venues — replace with shipped map paths after Meshy / art import.

#pragma once

#include "CoreMinimal.h"

namespace FELDigitalTwinVenuePaths
{
	/**
	 * Venice Beach arena — **must match** the cooked level asset name in Content (e.g. `VeniceBeach.umap` → `.../VeniceBeach.VeniceBeach`).
	 * Gold Master: aligned with `UFELAssetRegistrySubsystem` default venue (`/Game/FEL/Venues/VeniceBeach/`).
	 * Legacy folder name was `/Game/FEL/Maps/VeniceBeach_Arena` — if your project still uses that .umap, point this constant there instead.
	 */
	inline const TCHAR* VeniceBeachArena = TEXT("/Game/FEL/Venues/VeniceBeach/VeniceBeach.VeniceBeach");

	/** Same as `VeniceBeachArena` — kept for call sites that referenced a separate Venues path. */
	inline const TCHAR* VeniceBeachArenaVenues = TEXT("/Game/FEL/Venues/VeniceBeach/VeniceBeach.VeniceBeach");

	/** Dojo / Karate — must match cooked map (`Dojo.umap` under this folder). */
	inline const TCHAR* DojoStadium = TEXT("/Game/FEL/Venues/Dojo/Dojo.Dojo");

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
