// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: Expression Trigger System - Maps gameplay events to facial expressions

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELFaceRigTypes.h"
#include "FELExpressionTrigger.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogFELExprTrigger, Log, All);

/**
 * Active expression on a character.
 */
USTRUCT()
struct FFELActiveExpression
{
    GENERATED_BODY()

    EFELExpression Expression = EFELExpression::Neutral;
    float RemainingDuration = 0.f;
    float BlendInTime = 0.2f;
    float BlendOutTime = 0.5f;
    int32 Priority = 0;
    float ElapsedTime = 0.f;
};

/**
 * UFELExpressionTriggerSubsystem
 *
 * Central hub that maps gameplay events to facial expressions.
 * Characters register via their FELLiveLinkFaceComponent;
 * game systems fire events, and the subsystem routes the
 * appropriate expression preset to each affected character.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELExpressionTriggerSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;
    virtual void Deinitialize() override;

    // --- Trigger API ---

    /** Fire a gameplay event that triggers an expression on a specific actor. */
    UFUNCTION(BlueprintCallable, Category = "FEL|Expression")
    void TriggerExpression(AActor* TargetActor, EFELGameplayEvent Event);

    /** Fire a gameplay event on all registered actors. */
    UFUNCTION(BlueprintCallable, Category = "FEL|Expression")
    void TriggerExpressionAll(EFELGameplayEvent Event);

    /** Fire a gameplay event on the local player character. */
    UFUNCTION(BlueprintCallable, Category = "FEL|Expression")
    void TriggerPlayerExpression(EFELGameplayEvent Event);

    // --- Configuration ---

    /** Register a custom event-to-expression mapping. */
    UFUNCTION(BlueprintCallable, Category = "FEL|Expression")
    void RegisterTrigger(EFELGameplayEvent Event, const FFELExpressionTrigger& Trigger);

    /** Get the trigger data for a gameplay event. */
    UFUNCTION(BlueprintPure, Category = "FEL|Expression")
    FFELExpressionTrigger GetTriggerForEvent(EFELGameplayEvent Event) const;

    /** Get all registered triggers. */
    UFUNCTION(BlueprintPure, Category = "FEL|Expression")
    TMap<EFELGameplayEvent, FFELExpressionTrigger> GetAllTriggers() const { return EventTriggerMap; }

protected:
    void SetupDefaultTriggers();
    void ApplyExpressionToActor(AActor* Actor, const FFELExpressionTrigger& Trigger);

private:
    /** Event -> Expression mapping table. */
    UPROPERTY()
    TMap<EFELGameplayEvent, FFELExpressionTrigger> EventTriggerMap;
};
