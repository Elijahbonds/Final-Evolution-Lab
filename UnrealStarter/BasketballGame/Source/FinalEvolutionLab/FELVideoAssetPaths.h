// Auto-generated — Video Asset Paths for Final Evolution Lab
// Magic Reveal visual showcase videos mapped to UE5 MediaTexture assets
#pragma once

namespace FELVideoAssets
{
    static const TCHAR* VeniceBeachCourt = TEXT("/Game/FEL/Media/MagicReveal/Venice_Beach_Court_magic_reveal_Source");
    static const TCHAR* VeniceBallShop = TEXT("/Game/FEL/Media/MagicReveal/Venice_Ball_Shop_magic_reveal_Source");
    static const TCHAR* MuscleBeachGym = TEXT("/Game/FEL/Media/MagicReveal/Muscle_beach_gym_magic_reveal_Source");
    static const TCHAR* MuscleBeachStage = TEXT("/Game/FEL/Media/MagicReveal/Muscle_beach_stage_magic_reveal_Source");
    static const TCHAR* TennisCourts = TEXT("/Game/FEL/Media/MagicReveal/Venice_beach_tennis_courts_magic_reveal_Source");
    static const TCHAR* BlackTop = TEXT("/Game/FEL/Media/MagicReveal/Venice_Beach_Black_Top_magic_reveal_Source");
    static const TCHAR* Hoopbus = TEXT("/Game/FEL/Media/MagicReveal/Hoopbus_magic_reveal_Source");

    // Venue-to-video mapping
    static const TCHAR* GetVideoForVenue(const FString& VenueId)
    {
        if (VenueId == TEXT("venice_basketball")) return VeniceBeachCourt;
        if (VenueId == TEXT("marketplace")) return VeniceBallShop;
        if (VenueId == TEXT("training_gym")) return MuscleBeachGym;
        if (VenueId == TEXT("beach_tropical")) return MuscleBeachStage;
        if (VenueId == TEXT("tennis_court")) return TennisCourts;
        if (VenueId == TEXT("rooftop_cityscape")) return BlackTop;
        if (VenueId == TEXT("classic_nba_arena")) return Hoopbus;
        return nullptr;
    }
} // namespace FELVideoAssets
