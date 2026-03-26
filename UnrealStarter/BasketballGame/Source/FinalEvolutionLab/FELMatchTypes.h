// Copyright (c) Final Evolution Lab.
// Match lifecycle + result payload (Swift GameSessionResult parity + Unreal neuro fields).

#pragma once

#include "CoreMinimal.h"
#include "FELMatchTypes.generated.h"

/** High-level match lifecycle (Arena/Lab parity with Get Ready → Play → Result). */
UENUM(BlueprintType)
enum class EFELMatchPhase : uint8
{
	WaitingToStart UMETA(DisplayName = "Waiting (Tutorial / Countdown)"),
	InProgress UMETA(DisplayName = "In Progress"),
	MatchComplete UMETA(DisplayName = "Results"),
};

/**
 * Arena handoff block for `session_results.json` → Swift Vault / Film Vault parity ("one ecosystem").
 * Serialized as JSON object `arena_result` (snake_case keys).
 */
USTRUCT(BlueprintType)
struct FFELArenaResult
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	int32 FinalScore = 0;

	/** Post-match PRQ estimate (same pipeline as HUD / readiness snapshot). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	double NewPRQEstimate = 75.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	int32 EvolutionShardsEarned = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	int32 PerfectTimingCount = 0;

	/** True if at least one Bonds-Bounce "Perfect" occurred — enables Match Results replay CTA. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	bool bBestMomentReplayAvailable = false;
};

/**
 * Final match summary for UI, progression, and session_results.json.
 * Core fields align with FinalEvolutionLab/Models/GameSession.swift (GameSessionResult).
 * Extra keys (neuroPerformance, brainBrawlBoostCount, xpEarned) are ignored by Swift Codable if absent from CodingKeys.
 */
USTRUCT(BlueprintType)
struct FFELMatchResultSummary
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena|Economy")
	FFELArenaResult ArenaResult;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	int32 Score = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	int32 OpponentScore = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	double FinalPRQ = 75.0;

	/** 0–100 composite: PRQ + scoring + Brain Brawl mental-physical boosts. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	double NeuroPerformanceScore = 0.0;

	/** Brain Brawl quiz boosts → "Mental Sharpness" in session_results.json (Vault / social). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	double MentalSharpnessScore = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	int32 BrainBrawlBoostCount = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	int32 ShardsEarned = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	int32 XPEarned = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	FString GameModeId;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	int32 DurationSeconds = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	double PRQBonus = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	bool bEconomyEnabled = true;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	FString MatchEndBanner;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	FString MatchEndDetail;

	/** Sport-specific mastery 0–100 (Swift `masteryScore`). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	double MasteryScore = 0.0;

	/** Stable key for Vault grouping: accuracy, impact, timing, placement, etc. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match")
	FString MasteryMetricId = TEXT("composite");

	/** Keys like `mod1`…`mod12` completed in Unreal this session (see `session_results.json` → `academy_progress`). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match|Academy")
	TArray<FString> AcademyCompletedModuleKeys;

	/** Evolution Shards tied to new Academy completions this session (Swift merges + profile). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match|Academy")
	int32 AcademyEvolutionShardsEarned = 0;

	/** Brain Brawl Academy — your curated path id (from interest prompt / JSON curriculum). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match|BrainBrawl")
	FString BrainBrawlLocalPathId;

	/** Friend's parallel path id (readiness or auto-picked). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match|BrainBrawl")
	FString BrainBrawlOpponentPathId;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match|BrainBrawl")
	int32 BrainBrawlLocalCorrect = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match|BrainBrawl")
	int32 BrainBrawlOpponentCorrect = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Match|BrainBrawl")
	int32 BrainBrawlRoundSeconds = 0;
};
