// Copyright (c) Final Evolution Lab.
// Skateboarding — THPS-style trick chains, PRQ widens landing windows and stabilizes grinds.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FELArenaModeDefinitions.h"
#include "FELSkateboardingGameplayActor.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

UENUM(BlueprintType)
enum class EFELSkatePhase : uint8
{
	Cruising     UMETA(DisplayName = "Cruising / pushing"),
	Ollie        UMETA(DisplayName = "Ollie / launch"),
	Grind        UMETA(DisplayName = "Grinding"),
	Manual       UMETA(DisplayName = "Manual / nose manual"),
	AirTrick     UMETA(DisplayName = "Air trick"),
	Landing      UMETA(DisplayName = "Landing"),
	Bail         UMETA(DisplayName = "Bail / crash"),
};

USTRUCT(BlueprintType)
struct FFELSkateScoreCard
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly) float TotalScore = 0.f;
	UPROPERTY(BlueprintReadOnly) float BestComboScore = 0.f;
	UPROPERTY(BlueprintReadOnly) int32 TricksLanded = 0;
	UPROPERTY(BlueprintReadOnly) int32 GrindsCompleted = 0;
	UPROPERTY(BlueprintReadOnly) int32 ManualsCompleted = 0;
	UPROPERTY(BlueprintReadOnly) int32 Bails = 0;
	UPROPERTY(BlueprintReadOnly) float ComboMultiplier = 1.f;
	UPROPERTY(BlueprintReadOnly) float CurrentComboScore = 0.f;
};

UCLASS()
class FINALEVOLUTIONLAB_API AFELSkateboardingGameplayActor : public AActor
{
	GENERATED_BODY()

public:
	AFELSkateboardingGameplayActor();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Skate")
	EFELSkatePhase CurrentPhase = EFELSkatePhase::Cruising;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Skate")
	FFELSkateScoreCard ScoreCard;

	UFUNCTION(BlueprintCallable, Category = "FEL|Skate")
	void InitSkateSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);

	UFUNCTION(BlueprintCallable, Category = "FEL|Skate")
	void HandleOllieInput();

	UFUNCTION(BlueprintCallable, Category = "FEL|Skate")
	void HandleTrickInput(int32 TrickId);

	UFUNCTION(BlueprintCallable, Category = "FEL|Skate")
	void HandleGrindInput();

	UFUNCTION(BlueprintCallable, Category = "FEL|Skate")
	void HandleManualInput();

	UFUNCTION(BlueprintPure, Category = "FEL|Skate")
	FString BuildHudLine() const;

	virtual void Tick(float DeltaSeconds) override;

protected:
	virtual void BeginPlay() override;

private:
	TWeakObjectPtr<AFELBasketballGameMode> CachedGameMode;
	TWeakObjectPtr<AFELBasketballGameState> CachedGameState;

	float PhaseTimer = 0.f;
	float Balance01 = 1.f;
	float Speed01 = 0.5f;
	int32 ComboTrickCount = 0;
	float ComboGraceTimer = 0.f;

	void TransitionToPhase(EFELSkatePhase NewPhase);
	void CommitCombo();
	void TriggerBail();
	float GetPRQ() const;
	float GetLeakage() const;
};
