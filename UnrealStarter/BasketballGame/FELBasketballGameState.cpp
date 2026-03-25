// Copyright (c) Final Evolution Lab.

#include "FELBasketballGameState.h"
#include "FELArenaBridge.h"
#include "FinalEvolutionLab.h"

FString AFELBasketballGameState::GetPRQHUDLine() const
{
	return FString::Printf(TEXT("PRQ: %.0f"), ReadinessSnapshot.PRQScore);
}

FString AFELBasketballGameState::GetArenaAttributeHUDLine() const
{
	if (PrimaryAttributeLabel.IsEmpty())
	{
		return FString();
	}
	return FString::Printf(TEXT("%s: %.2f"), *PrimaryAttributeLabel, PrimaryAttributeDisplay);
}

void AFELBasketballGameState::SetReadinessContext(const FFELReadinessSnapshot& InSnap, const FString& InArenaGameModeId)
{
	ReadinessSnapshot = InSnap;
	ArenaGameModeId = InArenaGameModeId;
	PrimaryAttributeLabel = FELArenaBridge::AttributeLabelForGameModeId(InArenaGameModeId);
	PrimaryAttributeDisplay = static_cast<float>(FELArenaBridge::AttributeDisplay01To100(ReadinessSnapshot.PRQScore, InArenaGameModeId));
}

void AFELBasketballGameState::ApplyRules(FString InModeName, bool bInScoringEnabled, int32 InTargetScore, float InTimeLimitSeconds)
{
	ModeDisplayName = InModeName;
	bScoringEnabled = bInScoringEnabled;
	TargetScore = InTargetScore;
	TimeRemaining = InTimeLimitSeconds > 0.f ? InTimeLimitSeconds : 0.f;
	Score = 0;
	bMatchEnded = false;
	MatchEndBanner.Empty();
	MatchEndDetail.Empty();

	if (UWorld* W = GetWorld())
	{
		MatchStartWorldTimeSeconds = static_cast<double>(W->GetTimeSeconds());
	}
	else
	{
		MatchStartWorldTimeSeconds = 0.0;
	}
	PerfectTimingHitsThisMatch = 0;
}

void AFELBasketballGameState::AddPerfectTimingHit()
{
	if (!bMatchEnded)
	{
		PerfectTimingHitsThisMatch++;
	}
}

void AFELBasketballGameState::AddScore(int32 Delta)
{
	if (bMatchEnded || Delta == 0 || !bScoringEnabled)
	{
		return;
	}

	Score += Delta;

	if (TargetScore > 0 && Score >= TargetScore)
	{
		EndMatch(TEXT("Target reached!"), FString::Printf(TEXT("%d buckets"), Score));
	}
}

void AFELBasketballGameState::TickMatchTime(float DeltaSeconds)
{
	if (bMatchEnded || TimeRemaining <= 0.f)
	{
		return;
	}

	TimeRemaining = FMath::Max(0.f, TimeRemaining - DeltaSeconds);
	if (TimeRemaining <= 0.f)
	{
		EndMatch(TEXT("Time's up!"), FString::Printf(TEXT("Final buckets: %d"), Score));
	}
}

void AFELBasketballGameState::EndMatch(const FString& Banner, const FString& Detail)
{
	if (bMatchEnded)
	{
		return;
	}
	bMatchEnded = true;
	MatchEndBanner = Banner;
	MatchEndDetail = Detail;
	TimeRemaining = 0.f;
	OnMatchEnded.Broadcast();
}
