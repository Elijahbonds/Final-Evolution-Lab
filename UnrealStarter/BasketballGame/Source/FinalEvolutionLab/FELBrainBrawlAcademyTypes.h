// Copyright (c) Final Evolution Lab.
// Big Brain Academy–style curriculum domains + parsing helpers.

#pragma once

#include "CoreMinimal.h"
#include "FELBrainBrawlAcademyTypes.generated.h"

/** Cognitive pillars (Compute / Identify / Memorize / Analyze / Visualize) — educational framing. */
UENUM(BlueprintType)
enum class EFELBrainBrawlCurriculumDomain : uint8
{
	Compute UMETA(DisplayName = "Compute"),
	Identify UMETA(DisplayName = "Identify"),
	Memorize UMETA(DisplayName = "Memorize"),
	Analyze UMETA(DisplayName = "Analyze"),
	Visualize UMETA(DisplayName = "Visualize"),
};

FINALEVOLUTIONLAB_API EFELBrainBrawlCurriculumDomain FEL_ParseBrainBrawlDomain(const FString& Name);

/** One multiple-choice item (Brain Brawl bank — JSON + fallbacks). */
USTRUCT(BlueprintType)
struct FFELNeuroQuizItem
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|BrainBrawl")
	FString Question;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|BrainBrawl")
	TArray<FString> Answers;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|BrainBrawl")
	int32 CorrectIndex = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|BrainBrawl")
	EFELBrainBrawlCurriculumDomain Domain = EFELBrainBrawlCurriculumDomain::Analyze;

	/** `core` or interest path id from curriculum JSON. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|BrainBrawl")
	FString SourcePathId;

	/** Tags from JSON `pathIds` (e.g. core + sport_science). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|BrainBrawl")
	TArray<FString> PathIds;
};
