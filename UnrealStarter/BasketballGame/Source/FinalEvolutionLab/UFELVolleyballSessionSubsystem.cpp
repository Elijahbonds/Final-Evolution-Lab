// Copyright (c) Final Evolution Lab.

#include "UFELVolleyballSessionSubsystem.h"
#include "FELArenaModeDefinitions.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELTwelvePillarArenaGameplay.h"
#include "Math/UnrealMathUtility.h"

void UFELVolleyballSessionSubsystem::ResetForMatch(const bool bVolleyball)
{
	bSessionActive = bVolleyball;
	Phase = EVolleyPhase::Idle;
	PhaseTimer = 0.f;
	bPlayerServing = true;
	PlayerScore = 0;
	OpponentScore = 0;
	SetNumber = 1;
	PlayerSetsWon = 0;
	OpponentSetsWon = 0;
	SpikeTimingMarginMs = 30.f;
	RallyLength = 0;
	LastResultLine.Empty();
}

void UFELVolleyballSessionSubsystem::BeginServe(AFELBasketballGameMode* GameMode)
{
	Phase = EVolleyPhase::Serve;
	PhaseTimer = 0.f;
	RallyLength = 0;

	const float PRQ = GameMode ? GameMode->GetNeuroPRQScoreFloat() : 75.f;
	SpikeTimingMarginMs = FELTwelvePillarArenaGameplay::VolleyballSpikeTimingMarginMs(PRQ);
}

void UFELVolleyballSessionSubsystem::ResolveSpike(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState)
{
	RallyLength++;
	const float PRQ01 = GameMode ? GameMode->GetNeuroPRQScoreFloat() * 0.01f : 0.75f;
	const float TimingBonus = FMath::Clamp(SpikeTimingMarginMs / 38.f, 0.f, 1.f);
	const float WinChance = FMath::Clamp(0.35f + PRQ01 * 0.2f + TimingBonus * 0.15f, 0.25f, 0.8f);
	const bool bPlayerWins = FMath::FRand() < WinChance;

	AwardPoint(bPlayerWins, GameMode, GameState);
	LastResultLine = bPlayerWins
		? FString::Printf(TEXT("Kill! Rally %d · Timing margin %.0f ms"), RallyLength, SpikeTimingMarginMs)
		: FString::Printf(TEXT("Blocked! Rally %d"), RallyLength);
}

void UFELVolleyballSessionSubsystem::AwardPoint(const bool bPlayer, AFELBasketballGameMode* /*GameMode*/, AFELBasketballGameState* GameState)
{
	if (bPlayer)
	{
		PlayerScore++;
		if (GameState && GameState->IsScoringEnabled())
		{
			GameState->AddScore(1);
		}
	}
	else
	{
		OpponentScore++;
	}

	bPlayerServing = bPlayer;
	Phase = EVolleyPhase::Cooldown;
	PhaseTimer = 0.f;
}

void UFELVolleyballSessionSubsystem::CheckSetWin(AFELBasketballGameMode* /*GameMode*/, AFELBasketballGameState* GameState)
{
	const int32 WinScore = 25;
	const bool bPlayerWins = PlayerScore >= WinScore && PlayerScore - OpponentScore >= 2;
	const bool bOppWins = OpponentScore >= WinScore && OpponentScore - PlayerScore >= 2;

	if (!bPlayerWins && !bOppWins)
	{
		return;
	}

	if (bPlayerWins) PlayerSetsWon++;
	else OpponentSetsWon++;

	PlayerScore = 0;
	OpponentScore = 0;
	SetNumber++;

	const int32 SetsToWin = 2;
	if (PlayerSetsWon >= SetsToWin)
	{
		if (GameState && !GameState->HasMatchEnded())
		{
			GameState->EndMatch(TEXT("Match won!"),
				FString::Printf(TEXT("Sets: %d–%d"), PlayerSetsWon, OpponentSetsWon));
		}
	}
	else if (OpponentSetsWon >= SetsToWin)
	{
		if (GameState && !GameState->HasMatchEnded())
		{
			GameState->EndMatch(TEXT("Match lost."),
				FString::Printf(TEXT("Sets: %d–%d"), OpponentSetsWon, PlayerSetsWon));
		}
	}
}

void UFELVolleyballSessionSubsystem::ProgressSession(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const float DeltaSeconds)
{
	if (!bSessionActive || !GameMode || !GameState || GameState->HasMatchEnded())
	{
		return;
	}
	if (GameMode->CurrentMode != EFELArenaMode::Volleyball)
	{
		return;
	}

	PhaseTimer += DeltaSeconds;

	switch (Phase)
	{
	case EVolleyPhase::Idle:
		BeginServe(GameMode);
		break;
	case EVolleyPhase::Serve:
		if (PhaseTimer > 1.0f)
		{
			Phase = EVolleyPhase::Set;
			PhaseTimer = 0.f;
		}
		break;
	case EVolleyPhase::Set:
		if (PhaseTimer > 0.5f)
		{
			Phase = EVolleyPhase::Spike;
			PhaseTimer = 0.f;
		}
		break;
	case EVolleyPhase::Spike:
		if (PhaseTimer > 0.4f)
		{
			ResolveSpike(GameMode, GameState);
			CheckSetWin(GameMode, GameState);
		}
		break;
	case EVolleyPhase::PointResolved:
	case EVolleyPhase::Cooldown:
		if (PhaseTimer > 1.2f)
		{
			BeginServe(GameMode);
		}
		break;
	}
}

FString UFELVolleyballSessionSubsystem::BuildHudLine() const
{
	if (!bSessionActive)
	{
		return FString();
	}
	return FString::Printf(
		TEXT("Volleyball · Set %d (Sets %d–%d) · %d–%d · Spike margin %.0f ms · %s"),
		SetNumber, PlayerSetsWon, OpponentSetsWon,
		PlayerScore, OpponentScore,
		SpikeTimingMarginMs, *LastResultLine);
}
