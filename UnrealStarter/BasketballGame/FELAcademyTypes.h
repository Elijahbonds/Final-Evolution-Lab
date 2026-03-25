// Copyright (c) Final Evolution Lab.
// Vertical Velocity Academy — 12-module registry (IDs align with Swift `VerticalVelocityAcademyCurriculum`).

#pragma once

#include "CoreMinimal.h"
#include "FELAcademyTypes.generated.h"

UENUM(BlueprintType)
enum class EFELAcademyModuleId : uint8
{
	Mod1_CNSFreeway UMETA(DisplayName = "Mod1 — Bio-Electric Freeway"),
	Mod2_SFMAFMS UMETA(DisplayName = "Mod2 — SFMA/FMS GPS"),
	Mod3_IAP UMETA(DisplayName = "Mod3 — IAP Piston"),
	Mod4_MovementSnacks UMETA(DisplayName = "Mod4 — Movement Snacks"),
	Mod5_Slings UMETA(DisplayName = "Mod5 — Anatomy of the Sling"),
	Mod6_Correctives UMETA(DisplayName = "Mod6 — NMS Correctives"),
	Mod7_PJFTBB UMETA(DisplayName = "Mod7 — PJF / TBB Loaded Spring"),
	Mod8_RFDPenultimate UMETA(DisplayName = "Mod8 — RFD Penultimate"),
	Mod9_Plyos UMETA(DisplayName = "Mod9 — Elastic Engine (Plyos)"),
	Mod10_FlightBlueprint UMETA(DisplayName = "Mod10 — Flight Blueprint"),
	Mod11_Nutrition UMETA(DisplayName = "Mod11 — Bio-Molecular Fuel"),
	Mod12_SupplementSling UMETA(DisplayName = "Mod12 — Supplementing the Sling")
};

UENUM(BlueprintType)
enum class EFELJointLeakageBand : uint8
{
	Primed UMETA(DisplayName = "PRIMED"),
	Moderate UMETA(DisplayName = "MODERATE"),
	Leaking UMETA(DisplayName = "LEAKING")
};

USTRUCT(BlueprintType)
struct FFELAcademyModuleEntry
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Academy")
	EFELAcademyModuleId ModuleIdEnum = EFELAcademyModuleId::Mod1_CNSFreeway;

	/** Swift / JSON id: mod1 … mod12 */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Academy")
	FString ModuleKey;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Academy")
	FText Title;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Academy")
	FText CategoryTag;
};

USTRUCT(BlueprintType)
struct FFELAcademyPrescriptionResult
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Academy")
	TArray<FString> HighPriorityModuleKeys;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Academy")
	TArray<FString> MediumPriorityModuleKeys;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Academy")
	FString Rationale;
};
