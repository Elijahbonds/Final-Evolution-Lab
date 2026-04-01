// Copyright (c) Final Evolution Lab.

#include "FELArenaModeUX.h"

FString FELArenaModeUX::GetObjectiveSubtitle(const EFELArenaMode Mode)
{
	switch (Mode)
	{
	case EFELArenaMode::BasketballHeadToHead:
		return TEXT("Street 1v1 — chain movement into finishes above the rim. First to the target score wins.");
	case EFELArenaMode::BasketballDunkContest:
		return TEXT("Dunk contest — build style chains for a multiplier; made shots fill the contest meter.");
	case EFELArenaMode::Basketball3v3:
		return TEXT("Half-court shootout — two balls in play; first side to the target buckets wins.");
	case EFELArenaMode::Karate:
		return TEXT("Dojo — strike during the timing windows; footwork and spacing decide exchanges.");
	case EFELArenaMode::Baseball:
		return TEXT("Ballpark batting — swing inside the plate window; athlete readiness widens good timing.");
	case EFELArenaMode::Football:
		return TEXT("Kick return — alternate possessions; race to the touchdown target before the clock ends.");
	case EFELArenaMode::Soccer:
		return TEXT("Stadium — keep possession and finish on the goals; arena score uses points before time expires.");
	case EFELArenaMode::Golf:
		return TEXT("Links — stroke practice on the arena ball; reach the shot target or beat the session clock.");
	case EFELArenaMode::Tennis:
		return TEXT("Court — lateral movement and timed sets; rally scoring tracks points to the blitz target.");
	case EFELArenaMode::Volleyball:
		return TEXT("Sand court — read the tempo; timed match with rally points to the blitz target.");
	case EFELArenaMode::Gymnastics:
		return TEXT("Training floor — tempo-aware movement; hit the routine point target within the clock.");
	case EFELArenaMode::BrainBrawl:
		return TEXT("Academy quiz duel — answer each prompt; the round ends when the quiz timer reaches zero.");
	case EFELArenaMode::MarketBrowse:
		return TEXT("Sovereign Shop — explore the floor; interact with highlighted gear and captures.");
	case EFELArenaMode::Surfing:
		return TEXT("Surf line — PRQ widens balance windows and swell mitigation; hold your line score.");
	case EFELArenaMode::Skateboarding:
		return TEXT("Skate line — PRQ stabilizes trick fill and speed feel; chain balance into score.");
	case EFELArenaMode::Snowboarding:
		return TEXT("Snow line — PRQ adds edge grip and line tension; avoid wipeouts that trim the run.");
	default:
		return TEXT("Follow the on-screen score, timer, and prompts.");
	}
}

FString FELArenaModeUX::GetScoreTerm(const EFELArenaMode Mode)
{
	switch (Mode)
	{
	case EFELArenaMode::BasketballHeadToHead:
	case EFELArenaMode::BasketballDunkContest:
	case EFELArenaMode::Basketball3v3:
		return TEXT("Buckets");
	case EFELArenaMode::Baseball:
		return TEXT("Runs");
	case EFELArenaMode::Football:
	case EFELArenaMode::Soccer:
	case EFELArenaMode::Golf:
	case EFELArenaMode::Tennis:
	case EFELArenaMode::Volleyball:
	case EFELArenaMode::Gymnastics:
	case EFELArenaMode::Karate:
	case EFELArenaMode::Surfing:
	case EFELArenaMode::Skateboarding:
	case EFELArenaMode::Snowboarding:
		return TEXT("Points");
	case EFELArenaMode::BrainBrawl:
		return TEXT("Quiz");
	case EFELArenaMode::MarketBrowse:
		return TEXT("Browse");
	default:
		return TEXT("Score");
	}
}

FString FELArenaModeUX::GetControlFooterHint(const EFELArenaMode Mode)
{
	switch (Mode)
	{
	case EFELArenaMode::BrainBrawl:
#if UE_BUILD_SHIPPING
		return TEXT("Use the on-screen quiz controls to answer each round.");
#else
		return TEXT("Quiz UI — mouse or touch  |  R reloads athlete profile (development)");
#endif
	case EFELArenaMode::MarketBrowse:
		return TEXT("Move + look to navigate  |  Tap / trace shop hotspots");
	case EFELArenaMode::Surfing:
		return TEXT("WASD move  |  Mouse look  |  Line + balance use PRQ (see HUD)");
	case EFELArenaMode::Skateboarding:
		return TEXT("WASD move  |  Mouse look  |  Trick line + balance — PRQ widens windows");
	case EFELArenaMode::Snowboarding:
		return TEXT("WASD move  |  Mouse look  |  Carve line on TrainingFloor — avoid wipeouts");
	case EFELArenaMode::Baseball:
		return TEXT("Jump / Space / tap / shoot — swing  |  WASD move  |  Mouse look");
	default:
		return TEXT("WASD move  |  Mouse look  |  Space jump  |  Gamepad supported");
	}
}
