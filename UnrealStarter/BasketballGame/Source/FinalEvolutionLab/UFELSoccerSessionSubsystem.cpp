// Copyright (c) Final Evolution Lab.

#include "UFELSoccerSessionSubsystem.h"
#include "FELArenaModeDefinitions.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELTwelvePillarArenaGameplay.h"
#include "Math/UnrealMathUtility.h"

void UFELSoccerSessionSubsystem::ResetForMatch(const bool bSoccer)
{
	bSessionActive = bSoccer;
	Phase = ESoccerPhase::Idle;
	PhaseTimer = 0.f;
	bPlayerPossession = true;
	PlayerGoals = 0;
	OpponentGoals = 0;
	HalfNumber = 1;
	MatchClock = 0.f;
	HalfDuration = 90.f;
	ShotCurveStability = 0.8f;
	LastResultLine.Empty();
}

void UFELSoccerSessionSubsystem::BeginKickOff(AFELBasketballGameMode* GameMode)
{
	Phase = ESoccerPhase::KickOff;
	PhaseTimer = 0.f;
	bPlayerPossession = FMath::FRand() > 0.5f;

	const float PRQ = GameMode ? GameMode->GetNeuroPRQScoreFloat() : 75.f;
	ShotCurveStability = FELTwelvePillarArenaGameplay::SoccerShotCurveStabilityFromPRQ(PRQ, 0.5f);
}

void UFELSoccerSessionSubsystem::AttemptShot(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState)
{
	const float PRQ01 = GameMode ? GameMode->GetNeuroPRQScoreFloat() * 0.01f : 0.75f;

	if (bPlayerPossession)
	{
		const float GoalChance = FMath::Clamp(0.25f + PRQ01 * 0.2f + ShotCurveStability * 0.15f, 0.15f, 0.65f);
		if (FMath::FRand() < GoalChance)
		{
			PlayerGoals++;
			if (GameState && GameState->IsScoringEnabled())
			{
				GameState->AddScore(1);
			}
			LastResultLine = FString::Printf(TEXT("GOAL! %d–%d · Curve stability %.0f%%"),
				PlayerGoals, OpponentGoals, ShotCurveStability * 100.f);
			Phase = ESoccerPhase::GoalScored;
			PhaseTimer = 0.f;
			return;
		}
		LastResultLine = TEXT("Saved by keeper!");
	}
	else
	{
		const float OppGoalChance = FMath::Clamp(0.2f + (1.f - PRQ01) * 0.15f, 0.1f, 0.4f);
		if (FMath::FRand() < OppGoalChance)
		{
			OpponentGoals++;
			LastResultLine = FString::Printf(TEXT("Opponent scores. %d–%d"), PlayerGoals, OpponentGoals);
			Phase = ESoccerPhase::GoalScored;
			PhaseTimer = 0.f;
			return;
		}
		LastResultLine = TEXT("Great save!");
	}

	bPlayerPossession = !bPlayerPossession;
	Phase = ESoccerPhase::Midfield;
	PhaseTimer = 0.f;
}

void UFELSoccerSessionSubsystem::CheckHalfTime(AFELBasketballGameMode* /*GameMode*/, AFELBasketballGameState* GameState)
{
	if (MatchClock >= HalfDuration)
	{
		if (HalfNumber < 2)
		{
			HalfNumber++;
			MatchClock = 0.f;
			LastResultLine = FString::Printf(TEXT("Half time — %d–%d"), PlayerGoals, OpponentGoals);
			Phase = ESoccerPhase::Cooldown;
			PhaseTimer = 0.f;
		}
		else
		{
			if (GameState && !GameState->HasMatchEnded())
			{
				const FString Banner = PlayerGoals > OpponentGoals ? TEXT("You win!")
					: PlayerGoals < OpponentGoals ? TEXT("Opponent wins.")
					: TEXT("Draw!");
				GameState->EndMatch(Banner,
					FString::Printf(TEXT("Final: %d–%d"), PlayerGoals, OpponentGoals));
			}
		}
	}
}

void UFELSoccerSessionSubsystem::ProgressSession(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const float DeltaSeconds)
{
	if (!bSessionActive || !GameMode || !GameState || GameState->HasMatchEnded())
	{
		return;
	}
	if (GameMode->CurrentMode != EFELArenaMode::Soccer)
	{
		return;
	}

	MatchClock += DeltaSeconds;
	PhaseTimer += DeltaSeconds;

	switch (Phase)
	{
	case ESoccerPhase::Idle:
		BeginKickOff(GameMode);
		break;
	case ESoccerPhase::KickOff:
		if (PhaseTimer > 1.0f)
		{
			Phase = ESoccerPhase::Midfield;
			PhaseTimer = 0.f;
		}
		break;
	case ESoccerPhase::Midfield:
		if (PhaseTimer > 2.0f)
		{
			Phase = ESoccerPhase::Attack;
			PhaseTimer = 0.f;
		}
		break;
	case ESoccerPhase::Attack:
		if (PhaseTimer > 1.5f)
		{
			Phase = ESoccerPhase::Shot;
			PhaseTimer = 0.f;
		}
		break;
	case ESoccerPhase::Shot:
		if (PhaseTimer > 0.5f)
		{
			AttemptShot(GameMode, GameState);
			CheckHalfTime(GameMode, GameState);
		}
		break;
	case ESoccerPhase::Save:
		break;
	case ESoccerPhase::GoalScored:
	case ESoccerPhase::Cooldown:
		if (PhaseTimer > 2.5f)
		{
			BeginKickOff(GameMode);
		}
		break;
	}
}

FString UFELSoccerSessionSubsystem::BuildHudLine() const
{
	if (!bSessionActive)
	{
		return FString();
	}
	return FString::Printf(
		TEXT("Soccer · Half %d · %.0f' · %d–%d · Curve %.0f%% · %s"),
		HalfNumber, MatchClock, PlayerGoals, OpponentGoals,
		ShotCurveStability * 100.f, *LastResultLine);
}
