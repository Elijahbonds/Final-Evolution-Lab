// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "FELReadinessTypes.h"
#include "GameFramework/GameStateBase.h"
#include "FELBasketballGameState.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnFELMatchEndedSignature);

/**
 * Rules + score for all FEL basketball modes (local / single-player).
 */
UCLASS()
class FINALEVOLUTIONLAB_API AFELBasketballGameState : public AGameStateBase
{
	GENERATED_BODY()

public:
	int32 GetScore() const { return Score; }
	bool IsScoringEnabled() const { return bScoringEnabled; }
	bool HasMatchEnded() const { return bMatchEnded; }
	int32 GetTargetScore() const { return TargetScore; }
	float GetTimeRemaining() const { return TimeRemaining; }
	const FString& GetModeDisplayName() const { return ModeDisplayName; }
	const FString& GetMatchEndBanner() const { return MatchEndBanner; }
	const FString& GetMatchEndDetail() const { return MatchEndDetail; }

	const FFELReadinessSnapshot& GetReadinessSnapshot() const { return ReadinessSnapshot; }
	const FString& GetArenaGameModeId() const { return ArenaGameModeId; }
	double GetMatchStartWorldTimeSeconds() const { return MatchStartWorldTimeSeconds; }

	/** Bonds Bounce "Perfect" bands this match — drives Match Results replay CTA + `arena_result` export. */
	int32 GetPerfectTimingHits() const { return PerfectTimingHitsThisMatch; }

	UFUNCTION(BlueprintCallable, Category = "FEL|Match")
	void AddPerfectTimingHit();

	FString GetPRQHUDLine() const;
	FString GetArenaAttributeHUDLine() const;

	/**
	 * Called from game mode after GameState exists.
	 * `bDunkContestArcade` — dunk contest style meter; `bStreetJamArcade` — H2H/3v3 trick meter (disabled if dunk on).
	 */
	void ApplyRules(
		FString InModeName,
		bool bInScoringEnabled,
		int32 InTargetScore,
		float InTimeLimitSeconds,
		bool bDunkContestArcade = false,
		bool bStreetJamArcade = false,
		const FFELReadinessSnapshot* OptionalProfileForStreetJam = nullptr);

	bool IsDunkContestArcadeActive() const { return bDunkContestArcadeActive; }

	bool IsStreetJamArcadeActive() const { return bStreetJamArcadeActive; }

	float GetStreetJamScoreMultiplier() const { return StreetJamActiveScoreMultiplier; }

	/** Style-driven bucket multiplier (updated by `UFELDunkContestSessionSubsystem`). */
	float GetDunkContestScoreMultiplier() const { return DunkContestActiveScoreMultiplier; }

	FString GetDunkContestStyleHUDLine() const;

	UFUNCTION(BlueprintCallable, Category = "FEL|DunkContest")
	void SetDunkContestStyleHud(float StyleMeter0to100, float ScoreMultiplier, int32 ChainCount);

	FString GetStreetJamHUDLine() const;

	UFUNCTION(BlueprintCallable, Category = "FEL|StreetJam")
	void SetStreetJamHud(float TrickMeter0to100, float ScoreMultiplier, int32 BucketCombo, int32 GatherChain, bool bGamebreakerReady);

	/** PRQ + Swift GameModeId parity; refreshes HUD attribute labels. */
	void SetReadinessContext(const FFELReadinessSnapshot& InSnap, const FString& InArenaGameModeId);

	UFUNCTION(BlueprintCallable, Category = "FEL")
	void AddScore(int32 Delta);

	/** Countdown when InTimeLimitSeconds was set (>0). */
	void TickMatchTime(float DeltaSeconds);

	/** Fired when EndMatch runs (AFELBasketballGameMode handles rewards + session_results.json). */
	UPROPERTY(BlueprintAssignable, Category = "FEL|Match")
	FOnFELMatchEndedSignature OnMatchEnded;

	/** Authoritative match end (game mode, mode subsystems, internal tick). */
	void EndMatch(const FString& Banner, const FString& Detail);

protected:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	int32 Score = 0;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	bool bScoringEnabled = true;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	int32 TargetScore = 0;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	float TimeRemaining = 0.f;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	bool bMatchEnded = false;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	FString ModeDisplayName;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	FString MatchEndBanner;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL")
	FString MatchEndDetail;

	FFELReadinessSnapshot ReadinessSnapshot;
	FString ArenaGameModeId;
	FString PrimaryAttributeLabel;
	float PrimaryAttributeDisplay = 0.f;
	double MatchStartWorldTimeSeconds = 0.0;

	int32 PerfectTimingHitsThisMatch = 0;

	bool bDunkContestArcadeActive = false;
	float DunkContestStyleMeter01 = 0.f;
	float DunkContestActiveScoreMultiplier = 1.f;
	int32 DunkContestChainCount = 0;

	bool bStreetJamArcadeActive = false;
	float StreetJamTrickMeter01 = 0.f;
	float StreetJamActiveScoreMultiplier = 1.f;
	int32 StreetJamBucketCombo = 0;
	int32 StreetJamGatherChain = 0;
	bool bStreetJamGamebreakerReady = false;
};
