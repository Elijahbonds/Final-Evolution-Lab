// Copyright (c) Final Evolution Lab.

#include "UFELKickReturnSessionSubsystem.h"
#include "FELArenaModeDefinitions.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELCreatorCardResolver.h"
#include "FELDojoNeuralTempest.h"
#include "FELKickReturnSim.h"

void UFELKickReturnSessionSubsystem::ResetForMatch(const bool bFootballKickReturn)
{
	bSessionActive = bFootballKickReturn;
	if (bSessionActive)
	{
		FELKickReturnSim::Reset(Runtime);
	}
	else
	{
		Runtime = FFELKickReturnRuntime();
	}
}

void UFELKickReturnSessionSubsystem::ProgressSession(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const float DeltaSeconds)
{
	if (!bSessionActive || !GameMode || !GameState || GameState->HasMatchEnded())
	{
		return;
	}
	if (GameMode->CurrentMode != EFELArenaMode::Football)
	{
		return;
	}
	if (!GameState->IsScoringEnabled())
	{
		return;
	}

	const FFELReadinessSnapshot& Snap = GameState->GetReadinessSnapshot();
	const float PlayerPRQ = static_cast<float>(FMath::Clamp(Snap.PRQScore, 0.0, 100.0));
	float CE = 1.f;
	float CS = 1.f;
	UFELCreatorCard* Card = FFELCreatorCardResolver::ResolveFromReadiness(Snap);
	FELDojoNeuralTempest::ResolveCreatorCardComposites(Snap, Card, CE, CS);
	const float ArenaPerf = FMath::Clamp(FMath::Sqrt(CE * CS), 0.75f, 1.35f);
	const float GhostPRQ = GameMode->CurrentArenaRules.SportNeuro.KickReturnGhostOpponentPRQ;

	FELKickReturnSim::Tick(Runtime, DeltaSeconds, PlayerPRQ, ArenaPerf, GhostPRQ, GameMode->CurrentArenaRules.SportNeuro);

	if (GameState->HasMatchEnded())
	{
		return;
	}

	const int32 TDTarget = GameState->GetTargetScore();
	if (TDTarget > 0)
	{
		if (Runtime.PlayerTouchdowns >= TDTarget)
		{
			GameState->EndMatch(
				TEXT("Kick return — you win!"),
				FString::Printf(TEXT("%d touchdowns (race to %d)"), Runtime.PlayerTouchdowns, TDTarget));
			return;
		}
		if (Runtime.OpponentTouchdowns >= TDTarget)
		{
			GameState->EndMatch(
				TEXT("Kick return — ghost wins."),
				FString::Printf(TEXT("They reached %d TDs first (you had %d)."), Runtime.OpponentTouchdowns, Runtime.PlayerTouchdowns));
			return;
		}
	}
}

FString UFELKickReturnSessionSubsystem::BuildHudLine() const
{
	if (!bSessionActive)
	{
		return FString();
	}
	const TCHAR* Turn = Runtime.bPlayerTurn ? TEXT("Your possession") : TEXT("Opponent possession");
	return FString::Printf(
		TEXT("Kick return · Wave %d · %s · Yards %.0f · Stamina %.0f%% / %.0f%% · Touchdowns %d–%d"),
		Runtime.WaveIndex,
		Turn,
		Runtime.YardsOnField,
		Runtime.PlayerDurability01 * 100.f,
		Runtime.OpponentDurability01 * 100.f,
		Runtime.PlayerTouchdowns,
		Runtime.OpponentTouchdowns);
}
