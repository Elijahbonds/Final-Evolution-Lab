// Copyright (c) Final Evolution Lab.
// Bonds Bounce biometric payload for IFELBiometricReceiver (world-wide propagation).

#pragma once

#include "CoreMinimal.h"
#include "FELBiometricTypes.generated.h"

/** Snapshot subset pushed to Character, Ball, Environment, and other receivers. */
USTRUCT(BlueprintType)
struct FFELBiometricContext
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biometric")
	double PRQScore = 75.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biometric")
	double NeuralDrive = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biometric")
	double PopForce = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biometric")
	double VerticalEstimateInches = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biometric")
	double HangTimeScale = 1.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biometric")
	double KineticLeakageMultiplier = 1.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biometric")
	double EfficiencyScore = 0.0;

	/** SFMA multi-segmental rotation screen — `false` = FAIL → Spiral / Front fascial "red congestion" in Lab overlays. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biometric|SFMA")
	bool bSFMASpiralRotationScreenPass = true;
};
