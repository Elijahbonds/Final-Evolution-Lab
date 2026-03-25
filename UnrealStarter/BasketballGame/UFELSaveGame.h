// Copyright (c) Final Evolution Lab.
// Gold Master cross-platform persistence (venue, gear mult, Sovereign unlocks).

#pragma once

#include "CoreMinimal.h"
#include "FELAthleteStatsTypes.h"
#include "FELReadinessTypes.h"
#include "GameFramework/SaveGame.h"
#include "UFELSaveGame.generated.h"

/**
 * Serialized gear / venue state — survives app restarts (iOS shell + embedded UE).
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELSaveGame : public USaveGame
{
	GENERATED_BODY()

public:
	static const TCHAR* GetSlotName() { return TEXT("FELGoldMasterGear"); }
	static constexpr int32 UserSlotIndex = 0;

	/**
	 * Compare average peak-Z (JumpHeight) of the last 10 PerformanceHistory samples vs the 10 before that.
	 * If last-10 sample variance exceeds threshold, returns Inconclusive (no fatigue banner).
	 * If the recent average is more than 5% below the prior average, returns Fatigued.
	 */
	static EFELFatigueState GetJumpPerformanceTrend(const UFELSaveGame* Save);

	/** Universal sync: JSON (performanceHistory, unlockedSovereignSkins, allTimePeakZ) → XOR obfuscate → Base64. */
	static FString ExportSaveToJSON(const UFELSaveGame* Save);

	/** Max `FFELAthleteStats::JumpHeight` (peak Z velocity uu/s) in history — ascent shoot-tap rim snap / coach JSON. */
	static float GetAllTimePeakJumpZVelocity(const UFELSaveGame* Save);

	/**
	 * AUDIT_BIOMECHANICAL_ECOSYSTEM — ballistic consistency: System Scan flight time / vertical estimate vs engine `JumpZVelocity`.
	 * If violated, data is **Compromised** — Sovereign bonuses must not be recorded (`SaveGearState`).
	 */
	static bool Validation_StressTest_IsDataCompromised(const FFELReadinessSnapshot& ScanContext, float PeakJumpZVelocityUu);

	/** OpenLevel / Digital Twin default venue id (content path segment). */
	UPROPERTY(SaveGame, Category = "FEL|Save")
	FString CurrentVenue = TEXT("Luma_Venice_Shop");

	/** Last applied gear jump scale from readiness / C++ pipeline (1.0–1.06). */
	UPROPERTY(SaveGame, Category = "FEL|Save")
	float CachedGearJumpMult = 1.f;

	/** Sovereign / signature unlock ids, e.g. "Bonds_Apex_Ignition". */
	UPROPERTY(SaveGame, Category = "FEL|Save")
	TArray<FString> UnlockedSovereignSkins;

	/** AI Coach foundation — bounded jump / gear samples (trimmed in SaveGearState). */
	UPROPERTY(SaveGame, Category = "FEL|Save|Coach")
	TArray<FFELAthleteStats> PerformanceHistory;
};
