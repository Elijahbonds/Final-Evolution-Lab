// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: Gameplay Integration - Bridges face animation with all 17 game modes

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELFaceRigTypes.h"
#include "FELFaceGameplayIntegration.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogFELFaceGameplay, Log, All);

/**
 * Game mode context for facial animation behavior.
 */
USTRUCT(BlueprintType)
struct FFELFaceGameModeConfig
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    FString GameModeId;

    /** Enable Live Link face capture for this mode. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    bool bEnableLiveLinkCapture = true;

    /** Default expression when idle in this mode. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    EFELExpression IdleExpression = EFELExpression::Neutral;

    /** Default expression during active gameplay. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    EFELExpression ActiveExpression = EFELExpression::Determined;

    /** Expression intensity multiplier for this mode. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    float ExpressionIntensity = 1.0f;

    /** Whether NPCs should have facial animation in this mode. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    bool bNPCFacialAnimation = true;

    /** Max NPC faces animated simultaneously. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite)
    int32 MaxAnimatedNPCs = 4;
};

/**
 * UFELFaceGameplayIntegration
 *
 * Subsystem that configures facial animation behavior per game mode
 * and provides high-level APIs for triggering expressions
 * during gameplay, workouts, and cutscenes across all 17 modes.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELFaceGameplayIntegration : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;

    // --- Game Mode Management ---

    /** Notify the system that a game mode has started. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnGameModeStarted(const FString& GameModeId);

    /** Notify the system that a game mode has ended. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnGameModeEnded();

    /** Get config for a game mode. */
    UFUNCTION(BlueprintPure, Category = "FEL|FaceGameplay")
    FFELFaceGameModeConfig GetGameModeConfig(const FString& GameModeId) const;

    // --- Gameplay Expressions ---

    /** Player scored (basket, goal, point, etc). */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnPlayerScored();

    /** Player missed a shot/attempt. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnPlayerMissed();

    /** Player got blocked/tackled/hit. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnPlayerBlocked();

    /** Player won the game. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnGameWon();

    /** Player lost the game. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnGameLost();

    // --- Workout Expressions ---

    /** Exercise started. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnExerciseStarted();

    /** Exercise at max effort. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnMaxEffort();

    /** Exercise completed successfully. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnExerciseCompleted();

    /** Exercise failed. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnExerciseFailed();

    /** Recovery phase. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnRecovery();

    // --- Cutscene Expressions ---

    /** Start a cutscene dialogue sequence. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnCutsceneDialogue(AActor* Speaker);

    /** Cutscene reaction (non-speaker). */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnCutsceneReaction(AActor* Reactor, EFELExpression ReactionExpression);

    /** End cutscene. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void OnCutsceneEnded();

    // --- NPC Crowd Expressions ---

    /** Trigger crowd celebration (for scoring events). */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void TriggerCrowdCelebration();

    /** Trigger crowd disappointment (for opponent scoring). */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void TriggerCrowdDisappointment();

    /** Set crowd to neutral/idle. */
    UFUNCTION(BlueprintCallable, Category = "FEL|FaceGameplay")
    void SetCrowdIdle();

protected:
    void SetupGameModeConfigs();
    void TriggerEventForPlayer(EFELGameplayEvent Event);

private:
    FString CurrentGameModeId;
    TMap<FString, FFELFaceGameModeConfig> GameModeConfigs;
};
