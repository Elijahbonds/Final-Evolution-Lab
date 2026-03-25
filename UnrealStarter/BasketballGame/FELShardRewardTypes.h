// Copyright (c) Final Evolution Lab.
// Evolution Shard reward table — aligned with Swift `ShardEconomy` / Fuel the Freeway (Abstract).

#pragma once

#include "CoreMinimal.h"
#include "FELShardRewardTypes.generated.h"

/** Single source for shard payouts (nutrition, arena, training). */
UENUM(BlueprintType)
enum class EFELShardRewardReason : uint8
{
	// Fuel the Freeway — Photo-to-Shard / manual log (Abstract table)
	StructuralRepair UMETA(DisplayName = "Structural Repair (+5)"),
	FascialElasticity UMETA(DisplayName = "Fascial Elasticity (+10)"),
	SignalVelocity UMETA(DisplayName = "Signal Velocity (+5)"),
	CongestionCleared UMETA(DisplayName = "Congestion Cleared (+5)"),

	// Arena / Lab — mirrors Swift `ShardReward.forGameResult`
	GameWin UMETA(DisplayName = "Game Win (+50)"),
	GameDraw UMETA(DisplayName = "Game Draw (+25)"),
	GameLoss UMETA(DisplayName = "Game Loss (+15)"),
	MatchComplete UMETA(DisplayName = "Match Complete (+5)"),
	ComboBonusPerStack UMETA(DisplayName = "Combo Bonus (+5 per combo tier)"),
	CriticalHitPerStack UMETA(DisplayName = "Critical Hit (+10 per stack)"),

	// Generic grant
	CustomAmount UMETA(DisplayName = "Custom (use AwardShardsRaw)")
};

USTRUCT(BlueprintType)
struct FFELShardLedgerEntry
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Economy")
	FString ReasonKey;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Economy")
	int64 Amount = 0;

	/** Unix seconds (UTC). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Economy")
	double TimeUnix = 0.0;
};

namespace FELShardRewardTable
{
	/** Shard amounts — keep in sync with `ShardEconomy.swift` / Abstract. */
	inline int64 GetAmount(EFELShardRewardReason Reason)
	{
		switch (Reason)
		{
		case EFELShardRewardReason::StructuralRepair:
			return 5;
		case EFELShardRewardReason::FascialElasticity:
			return 10;
		case EFELShardRewardReason::SignalVelocity:
			return 5;
		case EFELShardRewardReason::CongestionCleared:
			return 5;
		case EFELShardRewardReason::GameWin:
			return 50;
		case EFELShardRewardReason::GameDraw:
			return 25;
		case EFELShardRewardReason::GameLoss:
			return 15;
		case EFELShardRewardReason::MatchComplete:
			return 5;
		case EFELShardRewardReason::ComboBonusPerStack:
			return 5;
		case EFELShardRewardReason::CriticalHitPerStack:
			return 10;
		case EFELShardRewardReason::CustomAmount:
		default:
			return 0;
		}
	}

	inline FString ReasonToKey(EFELShardRewardReason Reason)
	{
		switch (Reason)
		{
		case EFELShardRewardReason::StructuralRepair: return TEXT("StructuralRepair");
		case EFELShardRewardReason::FascialElasticity: return TEXT("FascialElasticity");
		case EFELShardRewardReason::SignalVelocity: return TEXT("SignalVelocity");
		case EFELShardRewardReason::CongestionCleared: return TEXT("CongestionCleared");
		case EFELShardRewardReason::GameWin: return TEXT("GameWin");
		case EFELShardRewardReason::GameDraw: return TEXT("GameDraw");
		case EFELShardRewardReason::GameLoss: return TEXT("GameLoss");
		case EFELShardRewardReason::MatchComplete: return TEXT("MatchComplete");
		case EFELShardRewardReason::ComboBonusPerStack: return TEXT("ComboBonusPerStack");
		case EFELShardRewardReason::CriticalHitPerStack: return TEXT("CriticalHitPerStack");
		case EFELShardRewardReason::CustomAmount:
		default: return TEXT("CustomAmount");
		}
	}
}
