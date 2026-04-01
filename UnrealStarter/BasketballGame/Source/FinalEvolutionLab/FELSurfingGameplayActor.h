// Copyright (c) Final Evolution Lab.
// Surfing arena actor — PRQ scales wave-reading, balance recovery, and line commitment.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FELArenaModeDefinitions.h"
#include "FELSurfingGameplayActor.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

UENUM(BlueprintType)
enum class EFELSurfWavePhase : uint8
{
	Paddling    UMETA(DisplayName = "Paddling out"),
	Takeoff     UMETA(DisplayName = "Takeoff / pop-up"),
	Riding      UMETA(DisplayName = "Riding the wave"),
	Cutback     UMETA(DisplayName = "Cutback / carve"),
	TubeRide    UMETA(DisplayName = "Tube ride"),
	Aerial      UMETA(DisplayName = "Aerial / air"),
	Wipeout     UMETA(DisplayName = "Wipeout"),
};

USTRUCT(BlueprintType)
struct FFELSurfScoreCard
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly) float WaveScore = 0.f;
	UPROPERTY(BlueprintReadOnly) int32 WavesRidden = 0;
	UPROPERTY(BlueprintReadOnly) int32 TubesCompleted = 0;
	UPROPERTY(BlueprintReadOnly) int32 AerialsLanded = 0;
	UPROPERTY(BlueprintReadOnly) int32 Wipeouts = 0;
	UPROPERTY(BlueprintReadOnly) float BestWaveScore = 0.f;
	UPROPERTY(BlueprintReadOnly) float StyleMeter = 0.f;
};

UCLASS()
class FINALEVOLUTIONLAB_API AFELSurfingGameplayActor : public AActor
{
	GENERATED_BODY()

public:
	AFELSurfingGameplayActor();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Surf")
	EFELSurfWavePhase CurrentPhase = EFELSurfWavePhase::Paddling;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Surf")
	FFELSurfScoreCard ScoreCard;

	UFUNCTION(BlueprintCallable, Category = "FEL|Surf")
	void InitSurfSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);

	UFUNCTION(BlueprintCallable, Category = "FEL|Surf")
	void HandlePaddleInput();

	UFUNCTION(BlueprintCallable, Category = "FEL|Surf")
	void HandleTrickInput(int32 TrickIndex);

	UFUNCTION(BlueprintCallable, Category = "FEL|Surf")
	void HandleCutbackInput(float Direction);

	UFUNCTION(BlueprintPure, Category = "FEL|Surf")
	FString BuildHudLine() const;

	virtual void Tick(float DeltaSeconds) override;

protected:
	virtual void BeginPlay() override;

private:
	TWeakObjectPtr<AFELBasketballGameMode> CachedGameMode;
	TWeakObjectPtr<AFELBasketballGameState> CachedGameState;

	float WaveTimer = 0.f;
	float CurrentWaveScore = 0.f;
	float Balance01 = 1.f;
	float SwellIntensity = 0.5f;
	int32 ComboCount = 0;
	float ComboTimer = 0.f;

	void TransitionToPhase(EFELSurfWavePhase NewPhase);
	void ProgressPaddling(float DeltaSeconds);
	void ProgressRiding(float DeltaSeconds);
	void ProgressTubeRide(float DeltaSeconds);
	void TriggerWipeout();
	void CommitWaveScore();
	float GetPRQ() const;
	float GetLeakage() const;
};
