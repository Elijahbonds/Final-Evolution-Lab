// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: Live Link Face Component - Attaches to characters for real-time facial animation

#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FELLiveLinkManager.h"
#include "FELFaceRigTypes.h"
#include "FELLiveLinkFaceComponent.generated.h"

DECLARE_LOG_CATEGORY_EXTERN(LogFELFaceComp, Log, All);

/**
 * UFELLiveLinkFaceComponent
 * 
 * Actor component that receives Live Link Face data from the manager
 * and applies it to a character's skeletal mesh morph targets.
 * Supports fallback to preset expressions when Live Link is disconnected.
 */
UCLASS(ClassGroup=(FEL), meta=(BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELLiveLinkFaceComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    UFELLiveLinkFaceComponent();

    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
    virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

    // --- Configuration ---

    /** The Live Link subject name to receive data from. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Face")
    FName LiveLinkSubjectName;

    /** Character type for selecting appropriate face rig configuration. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Face")
    EFELCharacterType CharacterType = EFELCharacterType::Player;

    /** Skeletal mesh component to apply morph targets to. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Face")
    TObjectPtr<USkeletalMeshComponent> TargetMeshComponent;

    /** Overall blend weight for facial animation (0=none, 1=full). */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Face", meta=(ClampMin=0.0, ClampMax=1.0))
    float FaceAnimationWeight = 1.0f;

    /** Smoothing factor for blend shape transitions. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Face", meta=(ClampMin=0.0, ClampMax=1.0))
    float TransitionSmoothness = 0.15f;

    /** Whether to use fallback expressions when disconnected. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Face")
    bool bUseFallbackExpressions = true;

    /** Fallback expression to use when Live Link is disconnected. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Face")
    EFELExpression FallbackExpression = EFELExpression::Neutral;

    /** LOD level for face rig (0=full 52 shapes, 1=32, 2=16). */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Face|Performance", meta=(ClampMin=0, ClampMax=2))
    int32 FaceRigLOD = 0;

    /** Distance from camera beyond which facial animation is disabled. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Face|Performance")
    float MaxAnimationDistance = 5000.f;

    /** Auto-detect the skeletal mesh component from the owner actor. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Face")
    bool bAutoDetectMesh = true;

    // --- Runtime API ---

    /** Force a specific expression (overrides Live Link data). */
    UFUNCTION(BlueprintCallable, Category = "FEL|Face")
    void SetExpression(EFELExpression Expression, float BlendTime = 0.3f);

    /** Clear forced expression and return to Live Link data. */
    UFUNCTION(BlueprintCallable, Category = "FEL|Face")
    void ClearForcedExpression(float BlendTime = 0.3f);

    /** Blend between Live Link data and a preset expression. */
    UFUNCTION(BlueprintCallable, Category = "FEL|Face")
    void BlendWithExpression(EFELExpression Expression, float BlendAlpha, float BlendTime = 0.3f);

    /** Get current active blend shape values. */
    UFUNCTION(BlueprintPure, Category = "FEL|Face")
    TMap<FName, float> GetCurrentBlendShapes() const;

    /** Check if receiving Live Link data. */
    UFUNCTION(BlueprintPure, Category = "FEL|Face")
    bool IsReceivingLiveLinkData() const { return bIsReceivingData; }

    /** Get current expression state. */
    UFUNCTION(BlueprintPure, Category = "FEL|Face")
    EFELExpression GetCurrentExpression() const { return CurrentExpression; }

protected:
    void ApplyBlendShapesToMesh(const TMap<FName, float>& BlendShapes);
    void UpdateFallbackExpression(float DeltaTime);
    void UpdateLODFromDistance();
    TMap<FName, float> GetExpressionBlendShapes(EFELExpression Expression) const;
    TMap<FName, float> LerpBlendShapes(const TMap<FName, float>& A, const TMap<FName, float>& B, float Alpha) const;
    int32 GetBlendShapeCountForLOD(int32 LOD) const;

private:
    UFELLiveLinkManager* LiveLinkManager = nullptr;
    TMap<FName, float> CurrentBlendShapeValues;
    TMap<FName, float> TargetBlendShapeValues;
    EFELExpression CurrentExpression = EFELExpression::Neutral;
    bool bIsReceivingData = false;
    bool bForcedExpression = false;
    float ForcedExpressionBlend = 0.f;
    float ForcedExpressionBlendTarget = 0.f;
    float ExpressionBlendSpeed = 3.3f;
    float TimeSinceLastData = 0.f;
    float FallbackTimeout = 2.0f;
};
