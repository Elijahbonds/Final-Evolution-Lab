// Copyright (c) Final Evolution Lab.
// Snowboarding — SSX-style carving + trick system; PRQ scales edge grip and air control.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FELArenaModeDefinitions.h"
#include "FELSnowboardingGameplayActor.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

UENUM(BlueprintType)
enum class EFELSnowPhase : uint8
{
	Carving      UMETA(DisplayName = "Carving / riding"),
	Jump         UMETA(DisplayName = "Jump / kicker"),
	AirTrick     UMETA(DisplayName = "Air trick"),
	Rail         UMETA(DisplayName = "Rail / jib"),
	Landing      UMETA(DisplayName = "Landing"),
	Crash        UMETA(DisplayName = "Crash / yard sale"),
	FinishLine   UMETA(DisplayName = "Finish line"),
};

USTRUCT(BlueprintType)
struct FFELSnowScoreCard
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly) float TotalScore = 0.f;
	UPROPERTY(BlueprintReadOnly) float BestTrickScore = 0.f;
	UPROPERTY(BlueprintReadOnly) int32 TricksLanded = 0;
	UPROPERTY(BlueprintReadOnly) int32 RailsCompleted = 0;
	UPROPERTY(BlueprintReadOnly) int32 Crashes = 0;
	UPROPERTY(BlueprintReadOnly) float Speed01 = 0.5f;
	UPROPERTY(BlueprintReadOnly) float EdgeGrip01 = 1.f;
	UPROPERTY(BlueprintReadOnly) float ComboMultiplier = 1.f;
	UPROPERTY(BlueprintReadOnly) float CurrentRunScore = 0.f;
	UPROPERTY(BlueprintReadOnly) float DistanceMeters = 0.f;
};

UCLASS()
class FINALEVOLUTIONLAB_API AFELSnowboardingGameplayActor : public AActor
{
	GENERATED_BODY()

public:
	AFELSnowboardingGameplayActor();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Snow")
	EFELSnowPhase CurrentPhase = EFELSnowPhase::Carving;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Snow")
	FFELSnowScoreCard ScoreCard;

	UFUNCTION(BlueprintCallable, Category = "FEL|Snow")
	void InitSnowSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);

	UFUNCTION(BlueprintCallable, Category = "FEL|Snow")
	void HandleCarveInput(float Direction);

	UFUNCTION(BlueprintCallable, Category = "FEL|Snow")
	void HandleJumpInput();

	UFUNCTION(BlueprintCallable, Category = "FEL|Snow")
	void HandleTrickInput(int32 TrickId);

	UFUNCTION(BlueprintCallable, Category = "FEL|Snow")
	void HandleRailInput();

	UFUNCTION(BlueprintPure, Category = "FEL|Snow")
	FString BuildHudLine() const;

	virtual void Tick(float DeltaSeconds) override;

protected:
	virtual void BeginPlay() override;

private:
	TWeakObjectPtr<AFELBasketballGameMode> CachedGameMode;
	TWeakObjectPtr<AFELBasketballGameState> CachedGameState;

	float PhaseTimer = 0.f;
	int32 ComboTrickCount = 0;
	float ComboGraceTimer = 0.f;
	float SlopeGrade = 0.5f;

	void TransitionToPhase(EFELSnowPhase NewPhase);
	void CommitRunScore();
	void TriggerCrash();
	float GetPRQ() const;
	float GetLeakage() const;
};
