// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "FELSystemScanTypes.generated.h"

UENUM(BlueprintType)
enum class EFELStartingTrack : uint8
{
	Foundations UMETA(DisplayName = "Foundations"),
	Flight UMETA(DisplayName = "Flight"),
	Elite UMETA(DisplayName = "Elite")
};

USTRUCT(BlueprintType)
struct FFELSystemScanOutput
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Scan")
	double PRQ0to100 = 75.0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Scan")
	double VerticalEstimateInches = 26.0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Scan")
	double FlightTimeSeconds = 0.5;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Scan")
	FString MovementGrade;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Scan")
	FString RecommendedTrack;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Scan")
	EFELStartingTrack StartingTrack = EFELStartingTrack::Foundations;

	/** Neuro-Mechanic: same vertical inches drives jump potential (`FELNeuroMechanicPhysics::PotentialJumpZFromVerticalInches`). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Scan")
	float NeuroVerticalPotentialJumpZ = 520.f;
};

USTRUCT(BlueprintType)
struct FFELAthleteHubDisplay
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Hub")
	bool bPrimed = false;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Hub")
	double PRQGauge = 0.0;

	/** 0 = cool (primed), 1 = hot (leaking). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Hub")
	double HeatAnkle = 0.0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Hub")
	double HeatKnee = 0.0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Hub")
	double HeatHip = 0.0;
};
