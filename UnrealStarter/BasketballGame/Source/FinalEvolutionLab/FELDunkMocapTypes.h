// Copyright (c) Final Evolution Lab.
// Dunk reference mocap — archetype buckets + named pro lists (DeepMotion / FBX imports).

#pragma once

#include "CoreMinimal.h"
#include "UObject/SoftObjectPtr.h"
#include "FELDunkMocapTypes.generated.h"

class UAnimMontage;

/** Common dunk shapes for catalog slots (assign montages per bucket in `UFELAcademyMocapCatalogSubsystem`). */
UENUM(BlueprintType)
enum class EFELDunkMocapArchetype : uint8
{
	Generic UMETA(DisplayName = "Generic / Exhibition"),
	Windmill UMETA(DisplayName = "Windmill"),
	Tomahawk UMETA(DisplayName = "Tomahawk / Power"),
	Eastbay UMETA(DisplayName = "Eastbay / Between legs (front)"),
	BetweenTheLegs UMETA(DisplayName = "Between the legs (variation)"),
	Spin360 UMETA(DisplayName = "360 / Spin"),
	AlleyOop UMETA(DisplayName = "Alley-oop / Lob finish"),
	Reverse UMETA(DisplayName = "Reverse / Baseline"),
	TwoHandPower UMETA(DisplayName = "Two-hand power"),
	Cradle UMETA(DisplayName = "Cradle / Honey dip style"),
	FreeThrowApproach UMETA(DisplayName = "Long approach / FT-line style"),
	EFELDunkMocapArchetype_MAX UMETA(Hidden)
};

/** Montage list per archetype (UHT-friendly map value). */
USTRUCT(BlueprintType)
struct FFELDunkArchetypeClipBucket
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Mocap")
	TArray<TSoftObjectPtr<UAnimMontage>> Montages;
};

/** Extra dunkers beyond fixed Elijah / Amir arrays — add rows in the subsystem defaults. */
USTRUCT(BlueprintType)
struct FFELNamedDunkerMocapList
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Mocap")
	FName DunkerSlug;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Mocap")
	TArray<TSoftObjectPtr<UAnimMontage>> Montages;
};
