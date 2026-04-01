// Copyright (c) Final Evolution Lab.

#include "UFELTennisSessionSubsystem.h"
#include "FELArenaModeDefinitions.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELTwelvePillarArenaGameplay.h"
#include "Math/UnrealMathUtility.h"

void UFELTennisSessionSubsystem::ResetForMatch(const bool bTennis)
{
	bSessionActive = bTennis;
	Phase = ETennisPhase::Idle;
	PhaseTimer = 0.f;
	bPlayerServing = true;
	PlayerGames = 0;
	OpponentGames = 0;
	PlayerPoints = 0;
	OpponentPoints = 0;
	RallyCount = 0;
	AceConeHalfAngle = 3.f;
	LastResultLine.Empty();
}

FString UFELTennisSessionSubsystem::TennisPointLabel(const int32 Points)
{
	switch (Points)
	{
	case 0: return TEXT("0");
	case 1: return TEXT("15");
	case 2: return TEXT("30");
	case 3: return TEXT("40");
	default: return TEXT("AD");
	}
}

void UFELTennisSessionSubsystem::BeginServe(AFELBasketballGameMode* GameMode)
{
	Phase = ETennisPhase::Serve;
	PhaseTimer = 0.f;
	RallyCount = 0;

	const float PRQ = GameMode ? GameMode->GetNeuroPRQScoreFloat() : 75.f;
	AceConeHalfAngle = FELTwelvePillarArenaGameplay::TennisServeAceConeHalfAngleDeg(PRQ);
}

void UFELTennisSessionSubsystem::ResolveRally(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState)
{
	RallyCount++;
	const float PRQ01 = GameMode ? GameMode->GetNeuroPRQScoreFloat() * 0.01f : 0.75f;
	const float WinChance = FMath::Clamp(0.4f + PRQ01 * 0.25f, 0.3f, 0.75f);
	const bool bPlayerWins = FMath::FRand() < WinChance;

	if (bPlayerServing && RallyCount == 1 && FMath::FRand() < AceConeHalfAngle * 0.04f)
	{
		AwardPoint(true, GameMode, GameState);
		LastResultLine = TEXT("ACE!");
		return;
	}

	AwardPoint(bPlayerWins, GameMode, GameState);
	LastResultLine = bPlayerWins ? TEXT("Winner!") : TEXT("Opponent takes point.");
}

void UFELTennisSessionSubsystem::AwardPoint(const bool bPlayer, AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState)
{
	if (bPlayer) PlayerPoints++;
	else OpponentPoints++;

	if (GameState && GameState->IsScoringEnabled() && bPlayer)
	{
		GameState->AddScore(1);
	}

	if (PlayerPoints >= 4 && PlayerPoints - OpponentPoints >= 2)
	{
		PlayerGames++;
		PlayerPoints = 0;
		OpponentPoints = 0;
		bPlayerServing = !bPlayerServing;
		CheckGameWin(GameMode, GameState);
	}
	else if (OpponentPoints >= 4 && OpponentPoints - PlayerPoints >= 2)
	{
		OpponentGames++;
		PlayerPoints = 0;
		OpponentPoints = 0;
		bPlayerServing = !bPlayerServing;
		CheckGameWin(GameMode, GameState);
	}

	Phase = ETennisPhase::Cooldown;
	PhaseTimer = 0.f;
}

void UFELTennisSessionSubsystem::CheckGameWin(AFELBasketballGameMode* /*GameMode*/, AFELBasketballGameState* GameState)
{
	const int32 GamesToWin = 6;
	if (PlayerGames >= GamesToWin && PlayerGames - OpponentGames >= 2)
	{
		if (GameState && !GameState->HasMatchEnded())
		{
			GameState->EndMatch(
				TEXT("Set won!"),
				FString::Printf(TEXT("Games: %d–%d"), PlayerGames, OpponentGames));
		}
	}
	else if (OpponentGames >= GamesToWin && OpponentGames - PlayerGames >= 2)
	{
		if (GameState && !GameState->HasMatchEnded())
		{
			GameState->EndMatch(
				TEXT("Set lost."),
				FString::Printf(TEXT("Games: %d–%d"), OpponentGames, PlayerGames));
		}
	}
}

void UFELTennisSessionSubsystem::ProgressSession(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const float DeltaSeconds)
{
	if (!bSessionActive || !GameMode || !GameState || GameState->HasMatchEnded())
	{
		return;
	}
	if (GameMode->CurrentMode != EFELArenaMode::Tennis)
	{
		return;
	}

	PhaseTimer += DeltaSeconds;

	switch (Phase)
	{
	case ETennisPhase::Idle:
		BeginServe(GameMode);
		break;
	case ETennisPhase::Serve:
		if (PhaseTimer > 1.2f)
		{
			Phase = ETennisPhase::Rally;
			PhaseTimer = 0.f;
		}
		break;
	case ETennisPhase::Rally:
		if (PhaseTimer > 0.6f)
		{
			ResolveRally(GameMode, GameState);
		}
		break;
	case ETennisPhase::PointScored:
	case ETennisPhase::Cooldown:
		if (PhaseTimer > 1.5f)
		{
			BeginServe(GameMode);
		}
		break;
	}
}

FString UFELTennisSessionSubsystem::BuildHudLine() const
{
	if (!bSessionActive)
	{
		return FString();
	}
	return FString::Printf(
		TEXT("Tennis · Games %d–%d · %s–%s · Rally %d · Ace cone %.1f° · %s"),
		PlayerGames, OpponentGames,
		*TennisPointLabel(PlayerPoints), *TennisPointLabel(OpponentPoints),
		RallyCount, AceConeHalfAngle, *LastResultLine);
}
