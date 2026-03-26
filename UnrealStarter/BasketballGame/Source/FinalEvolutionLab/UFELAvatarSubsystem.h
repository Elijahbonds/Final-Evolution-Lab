// Copyright (c) Final Evolution Lab.
// Scan-driven avatar calibration + Neuro vertical potential (links to `FELNeuroMechanicPhysics`).

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELSystemScanTypes.h"
#include "UFELAvatarSubsystem.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFELAvatarSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;

	/** Apply latest scan: starting track, cached neuro jump Z from vertical inches. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Avatar")
	void ApplySystemScanOutput(const FFELSystemScanOutput& Scan);

	UFUNCTION(BlueprintPure, Category = "FEL|Avatar")
	EFELStartingTrack GetStartingTrack() const { return StartingTrack; }

	/** Same input as Swift `verticalEstimateInches` → `PotentialJumpZFromVerticalInches`. */
	UFUNCTION(BlueprintPure, Category = "FEL|Avatar|NeuroMechanic")
	float GetNeuroVerticalPotentialJumpZ() const { return NeuroVerticalPotentialJumpZ; }

	UFUNCTION(BlueprintPure, Category = "FEL|Avatar")
	double GetLastVerticalEstimateInches() const { return LastVerticalInches; }

	UFUNCTION(BlueprintPure, Category = "FEL|Avatar|Scan")
	double GetLastPRQ0to100() const { return LastPRQ0to100; }

	/** 0…1 kinetic heat — Athlete Hub / readiness JSON; default primed until bridge writes scan. */
	UFUNCTION(BlueprintPure, Category = "FEL|Avatar|Scan")
	float GetKineticHeatAnkle01() const { return KineticHeatAnkle01; }

	UFUNCTION(BlueprintPure, Category = "FEL|Avatar|Scan")
	float GetKineticHeatKnee01() const { return KineticHeatKnee01; }

	UFUNCTION(BlueprintPure, Category = "FEL|Avatar|Scan")
	float GetKineticHeatHip01() const { return KineticHeatHip01; }

	UFUNCTION(BlueprintPure, Category = "FEL|Avatar|Scan")
	float GetKineticLeakageMultiplier() const { return KineticLeakageMultiplier; }

	/** Swift / `readiness_snapshot.json` bridge — only inputs that should tune `ApplyReadiness` with scan PRQ + neuro Z. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Avatar|Scan")
	void SetKineticHeatFromReadiness(float Ankle01, float Knee01, float Hip01, float InLeakageMultiplier);

private:
	UPROPERTY()
	EFELStartingTrack StartingTrack = EFELStartingTrack::Foundations;

	float NeuroVerticalPotentialJumpZ = 520.f;
	double LastVerticalInches = 26.0;
	double LastPRQ0to100 = 75.0;

	float KineticHeatAnkle01 = 0.12f;
	float KineticHeatKnee01 = 0.12f;
	float KineticHeatHip01 = 0.12f;
	float KineticLeakageMultiplier = 1.f;
};
