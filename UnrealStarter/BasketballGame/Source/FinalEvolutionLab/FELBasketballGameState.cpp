// Copyright (c) Final Evolution Lab.

#include "FELBasketballGameState.h"
#include "FELArenaBridge.h"
#include "FELReadinessTypes.h"
#include "UFELDunkContestSessionSubsystem.h"
#include "UFELStreetJamSessionSubsystem.h"
#include "Engine/World.h"
#include "FinalEvolutionLab.h"
#include "Engine/GameInstance.h"
#include "Math/UnrealMathUtility.h"

FString AFELBasketballGameState::GetPRQHUDLine() const
{
	return FString::Printf(TEXT("Athlete readiness (PRQ): %.0f"), ReadinessSnapshot.PRQScore);
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

FString AFELBasketballGameState::GetDunkContestStyleHUDLine() const
{
	if (!bDunkContestArcadeActive)
	{
		return FString();
	}
	return FString::Printf(
		TEXT("Style %.0f%%  x%.2f  Chain x%d"),
		DunkContestStyleMeter01 * 100.f,
		DunkContestActiveScoreMultiplier,
		DunkContestChainCount);
}

void AFELBasketballGameState::SetDunkContestStyleHud(const float StyleMeter0to100, const float ScoreMultiplier, const int32 ChainCount)
{
	DunkContestStyleMeter01 = FMath::Clamp(StyleMeter0to100 / 100.f, 0.f, 1.f);
	DunkContestActiveScoreMultiplier = FMath::Clamp(ScoreMultiplier, 1.f, 12.f);
	DunkContestChainCount = FMath::Max(0, ChainCount);
}

FString AFELBasketballGameState::GetStreetJamHUDLine() const
{
	if (!bStreetJamArcadeActive)
	{
		return FString();
	}
	const FString Breaker = bStreetJamGamebreakerReady ? TEXT("  ·  GAMEBREAKER!") : TEXT("");
	return FString::Printf(
		TEXT("Street x%.2f · Trick %.0f%% · Buckets x%d · Gather x%d%s"),
		StreetJamActiveScoreMultiplier,
		StreetJamTrickMeter01 * 100.f,
		StreetJamBucketCombo,
		StreetJamGatherChain,
		*Breaker);
}

void AFELBasketballGameState::SetStreetJamHud(
	const float TrickMeter0to100,
	const float ScoreMultiplier,
	const int32 BucketCombo,
	const int32 GatherChain,
	const bool bGamebreakerReady)
{
	StreetJamTrickMeter01 = FMath::Clamp(TrickMeter0to100 * 0.01f, 0.f, 2.f);
	StreetJamActiveScoreMultiplier = FMath::Clamp(ScoreMultiplier, 1.f, 8.f);
	StreetJamBucketCombo = FMath::Max(0, BucketCombo);
	StreetJamGatherChain = FMath::Max(0, GatherChain);
	bStreetJamGamebreakerReady = bGamebreakerReady;
}

void AFELBasketballGameState::ApplyRules(
	FString InModeName,
	const bool bInScoringEnabled,
	const int32 InTargetScore,
	const float InTimeLimitSeconds,
	const bool bDunkContestArcade,
	const bool bStreetJamArcadeIn,
	const FFELReadinessSnapshot* OptionalProfileForStreetJam)
{
	ModeDisplayName = InModeName;
	bScoringEnabled = bInScoringEnabled;
	TargetScore = InTargetScore;
	TimeRemaining = InTimeLimitSeconds > 0.f ? InTimeLimitSeconds : 0.f;
	Score = 0;
	bMatchEnded = false;
	MatchEndBanner.Empty();
	MatchEndDetail.Empty();

	bDunkContestArcadeActive = bDunkContestArcade;
	DunkContestStyleMeter01 = 0.f;
	DunkContestActiveScoreMultiplier = 1.f;
	DunkContestChainCount = 0;

	const bool bStreet = bStreetJamArcadeIn && bInScoringEnabled && !bDunkContestArcade;
	bStreetJamArcadeActive = bStreet;
	StreetJamTrickMeter01 = 0.f;
	StreetJamActiveScoreMultiplier = 1.f;
	StreetJamBucketCombo = 0;
	StreetJamGatherChain = 0;
	bStreetJamGamebreakerReady = false;

	if (UWorld* W = GetWorld())
	{
		MatchStartWorldTimeSeconds = static_cast<double>(W->GetTimeSeconds());
		if (UGameInstance* GI = W->GetGameInstance())
		{
			if (UFELDunkContestSessionSubsystem* Sub = GI->GetSubsystem<UFELDunkContestSessionSubsystem>())
			{
				Sub->ResetForMatch(bDunkContestArcade);
			}
			if (UFELStreetJamSessionSubsystem* SJam = GI->GetSubsystem<UFELStreetJamSessionSubsystem>())
			{
				SJam->ResetForMatch(bStreet, bStreet ? OptionalProfileForStreetJam : nullptr);
			}
		}
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
