// Copyright (c) Final Evolution Lab.
// AI Coach foundation — persisted athlete performance samples.

#pragma once

#include "CoreMinimal.h"
#include "Misc/DateTime.h"
#include "FELAthleteStatsTypes.generated.h"

/** AI Coach trend output — compare recent jump peaks vs prior window (see `UFELSaveGame::GetJumpPerformanceTrend`). */
UENUM(BlueprintType)
enum class EFELFatigueState : uint8
{
	Unknown UMETA(DisplayName = "Unknown"),
	Normal UMETA(DisplayName = "Normal"),
	Fatigued UMETA(DisplayName = "Fatigued"),
	/** Last-10 JumpHeight sample variance too high — do not surface fatigue UX (non-max efforts / noise). */
	Inconclusive UMETA(DisplayName = "Inconclusive"),
};

/** Single jump / session metric for Final Evolution AI Coach (System Scan lineage). */
USTRUCT(BlueprintType)
struct FFELAthleteStats
{
	GENERATED_BODY()

	/** Approximate apex contribution from last jump (uu ≈ cm); derived from peak Z velocity where noted in SaveGearState. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, SaveGame, Category = "FEL|Coach")
	float JumpHeight = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, SaveGame, Category = "FEL|Coach")
	FString GearID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, SaveGame, Category = "FEL|Coach")
	FDateTime Timestamp;
};
