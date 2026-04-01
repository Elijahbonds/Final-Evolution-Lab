// Copyright (c) Final Evolution Lab.
// Gymnastics floor — routine-based scoring with pass sequences, PRQ scales form and stamina.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FELArenaModeDefinitions.h"
#include "FELGymnasticsFloorActor.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

UENUM(BlueprintType)
enum class EFELGymnasticsPhase : uint8
{
	Preparing    UMETA(DisplayName = "Preparing / salute"),
	Tumbling     UMETA(DisplayName = "Tumbling pass"),
	Dance        UMETA(DisplayName = "Dance / artistry"),
	Leap         UMETA(DisplayName = "Leap sequence"),
	Balance      UMETA(DisplayName = "Balance hold"),
	Dismount     UMETA(DisplayName = "Dismount / final pass"),
	Scored       UMETA(DisplayName = "Scored / salute"),
};

USTRUCT(BlueprintType)
struct FFELGymnasticsScoreCard
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly) float DifficultyScore = 0.f;
	UPROPERTY(BlueprintReadOnly) float ExecutionScore = 10.f;
	UPROPERTY(BlueprintReadOnly) float ArtistryScore = 0.f;
	UPROPERTY(BlueprintReadOnly) int32 PassesCompleted = 0;
	UPROPERTY(BlueprintReadOnly) int32 DeductionCount = 0;
	UPROPERTY(BlueprintReadOnly) float Stamina01 = 1.f;
	UPROPERTY(BlueprintReadOnly) float FormQuality01 = 1.f;
};

UCLASS()
class FINALEVOLUTIONLAB_API AFELGymnasticsFloorActor : public AActor
{
	GENERATED_BODY()

public:
	AFELGymnasticsFloorActor();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Gymnastics")
	EFELGymnasticsPhase CurrentPhase = EFELGymnasticsPhase::Preparing;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Gymnastics")
	FFELGymnasticsScoreCard ScoreCard;

	UFUNCTION(BlueprintCallable, Category = "FEL|Gymnastics")
	void InitRoutine(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);

	UFUNCTION(BlueprintCallable, Category = "FEL|Gymnastics")
	void HandleTumblingInput(int32 SkillLevel);

	UFUNCTION(BlueprintCallable, Category = "FEL|Gymnastics")
	void HandleLeapInput();

	UFUNCTION(BlueprintCallable, Category = "FEL|Gymnastics")
	void HandleBalanceInput();

	UFUNCTION(BlueprintCallable, Category = "FEL|Gymnastics")
	void HandleDismountInput(int32 DismountDifficulty);

	UFUNCTION(BlueprintPure, Category = "FEL|Gymnastics")
	FString BuildHudLine() const;

	virtual void Tick(float DeltaSeconds) override;

protected:
	virtual void BeginPlay() override;

private:
	TWeakObjectPtr<AFELBasketballGameMode> CachedGameMode;
	TWeakObjectPtr<AFELBasketballGameState> CachedGameState;

	float PhaseTimer = 0.f;
	float RoutineTimer = 0.f;
	int32 TotalPasses = 4;

	void TransitionToPhase(EFELGymnasticsPhase NewPhase);
	void ApplyDeduction(float Amount, const FString& Reason);
	void FinalizeRoutine();
	float GetPRQ() const;
};
