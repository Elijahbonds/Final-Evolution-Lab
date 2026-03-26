// Copyright (c) Final Evolution Lab.
// Session + lifetime Shards/XP (Swift Vault / Social parity via session_results.json + local JSON).

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELMatchTypes.h"
#include "FELShardRewardTypes.h"
#include "FELProgressionSubsystem.generated.h"

/**
 * Tracks Shards and XP earned during the current game instance session and persists lifetime totals
 * to FEL/progression_session.json (Documents/FEL on iOS).
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELProgressionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;

	/** Called when a match completes; updates session + lifetime totals and saves disk cache. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Progression")
	void ApplyMatchRewards(const FFELMatchResultSummary& Summary);

	UFUNCTION(BlueprintPure, Category = "FEL|Progression")
	int64 GetSessionShardsEarned() const { return SessionShardsEarned; }

	UFUNCTION(BlueprintPure, Category = "FEL|Progression")
	int64 GetSessionXPEarned() const { return SessionXPEarned; }

	UFUNCTION(BlueprintPure, Category = "FEL|Progression")
	int64 GetLifetimeShards() const { return LifetimeShards; }

	UFUNCTION(BlueprintPure, Category = "FEL|Progression")
	int64 GetLifetimeXP() const { return LifetimeXP; }

	UFUNCTION(BlueprintCallable, Category = "FEL|Progression")
	void ResetSessionCounters();

	/** Table lookup — same values as `FELShardRewardTable::GetAmount`. */
	UFUNCTION(BlueprintPure, Category = "FEL|Progression|Economy")
	int64 GetShardAmountForReason(EFELShardRewardReason Reason) const;

	/** Awards shards for a single abstract reason; updates session + lifetime + ledger. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Progression|Economy")
	int64 AwardShardsForReason(EFELShardRewardReason Reason, int32 StackCount = 1);

	/** Fuel the Freeway — sums Structural (+5), Fascial (+10), Signal (+5), Congestion (+5) per flags. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Progression|Economy")
	int64 AwardMealNutritionShards(bool bStructuralRepair, bool bFascialElasticity, bool bSignalVelocity, bool bCongestionCleared);

	/** Raw grant (custom events); ReasonKey stored in ledger as "Custom". */
	UFUNCTION(BlueprintCallable, Category = "FEL|Progression|Economy")
	int64 AwardShardsRaw(int64 Amount, const FString& LedgerReasonKey);

	UFUNCTION(BlueprintPure, Category = "FEL|Progression|Economy")
	const TArray<FFELShardLedgerEntry>& GetRecentShardLedger() const { return RecentShardLedger; }

private:
	void LoadFromDisk();
	void SaveToDisk() const;
	void AppendLedger(const FString& ReasonKey, int64 Amount);
	static constexpr int32 MaxLedgerEntries = 128;

	int64 SessionShardsEarned = 0;
	int64 SessionXPEarned = 0;
	int64 LifetimeShards = 0;
	int64 LifetimeXP = 0;

	TArray<FFELShardLedgerEntry> RecentShardLedger;
};
