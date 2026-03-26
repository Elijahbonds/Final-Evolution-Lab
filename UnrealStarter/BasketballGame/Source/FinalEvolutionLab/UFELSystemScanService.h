// Copyright (c) Final Evolution Lab.
// Optional-video System Scan → PRQ, vertical, flight, movement grade (bridge to Swift `SystemScanResult`).

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELSystemScanTypes.h"
#include "UFELSystemScanService.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFELSystemScanService : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	/**
	 * Deterministic scan analysis (Unreal-side). Mirrors Swift scan policy in `FELPRQScanFormula` + `PRQ.fromVerticalInches`.
	 * @param Goal User goal string (e.g. "Jump Higher") — see `FELPRQScanFormula::GoalTierFromString`.
	 * @param OptionalVideoDurationSeconds <= 0 means no video; else used like Swift `duration * 0.4` flight heuristic.
	 * @param DeterminismSeed stable seed for repeatable outputs (e.g. hash of profile id).
	 */
	/**
	 * @param ToeOffFrameIndex / HeelStrikeFrameIndex / NominalVideoFrameRate — when valid (e.g. 120/240 fps capture),
	 *        flight time uses frame-accurate toe-off → heel-strike (see `FELFlightTimeAnalysis`).
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|SystemScan", meta = (AdvancedDisplay = "ToeOffFrameIndex, HeelStrikeFrameIndex, NominalVideoFrameRate"))
	void AnalyzeScan(
		const FString& Goal,
		float OptionalVideoDurationSeconds,
		int32 DeterminismSeed,
		FFELSystemScanOutput& OutScan,
		int32 ToeOffFrameIndex = -1,
		int32 HeelStrikeFrameIndex = -1,
		float NominalVideoFrameRate = 0.f) const;

	UFUNCTION(BlueprintPure, Category = "FEL|SystemScan")
	static EFELStartingTrack TrackEnumFromString(const FString& TrackName);
};
