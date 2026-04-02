// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: Live Link Face Component Implementation

#include "FELLiveLinkFaceComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "GameFramework/Character.h"
#include "Kismet/GameplayStatics.h"

DEFINE_LOG_CATEGORY(LogFELFaceComp);

UFELLiveLinkFaceComponent::UFELLiveLinkFaceComponent()
{
    PrimaryComponentTick.bCanEverTick = true;
    PrimaryComponentTick.TickGroup = TG_PrePhysics;
    SetComponentTickEnabled(true);
}

void UFELLiveLinkFaceComponent::BeginPlay()
{
    Super::BeginPlay();
    
    // Get Live Link Manager
    if (UGameInstance* GI = GetWorld()->GetGameInstance())
    {
        LiveLinkManager = GI->GetSubsystem<UFELLiveLinkManager>();
    }
    
    // Auto-detect skeletal mesh
    if (bAutoDetectMesh && !TargetMeshComponent)
    {
        if (ACharacter* Character = Cast<ACharacter>(GetOwner()))
        {
            TargetMeshComponent = Character->GetMesh();
        }
        else if (USkeletalMeshComponent* SMC = GetOwner()->FindComponentByClass<USkeletalMeshComponent>())
        {
            TargetMeshComponent = SMC;
        }
    }
    
    if (!TargetMeshComponent)
    {
        UE_LOG(LogFELFaceComp, Warning, TEXT("No skeletal mesh component found on %s. Face animation disabled."),
            *GetOwner()->GetName());
    }
    
    UE_LOG(LogFELFaceComp, Log, TEXT("Face component initialized on %s (Type=%d, Subject=%s)"),
        *GetOwner()->GetName(), (int32)CharacterType, *LiveLinkSubjectName.ToString());
}

void UFELLiveLinkFaceComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    LiveLinkManager = nullptr;
    Super::EndPlay(EndPlayReason);
}

void UFELLiveLinkFaceComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
    Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
    
    if (!TargetMeshComponent || FaceAnimationWeight <= 0.f) return;
    
    // Check LOD based on distance to camera
    UpdateLODFromDistance();
    
    // Try to get Live Link data
    bool bGotLiveLinkData = false;
    TMap<FName, float> LiveLinkBlendShapes;
    
    if (LiveLinkManager && LiveLinkManager->IsStreaming() && !LiveLinkSubjectName.IsNone())
    {
        LiveLinkBlendShapes = LiveLinkManager->GetBlendShapeValues(LiveLinkSubjectName);
        bGotLiveLinkData = LiveLinkBlendShapes.Num() > 0;
    }
    
    if (bGotLiveLinkData)
    {
        bIsReceivingData = true;
        TimeSinceLastData = 0.f;
        TargetBlendShapeValues = LiveLinkBlendShapes;
    }
    else
    {
        TimeSinceLastData += DeltaTime;
        
        if (TimeSinceLastData > FallbackTimeout)
        {
            bIsReceivingData = false;
            
            if (bUseFallbackExpressions)
            {
                UpdateFallbackExpression(DeltaTime);
            }
        }
    }
    
    // Handle forced expression blending
    if (bForcedExpression)
    {
        ForcedExpressionBlend = FMath::FInterpTo(ForcedExpressionBlend, ForcedExpressionBlendTarget,
            DeltaTime, ExpressionBlendSpeed);
        
        TMap<FName, float> ExpressionShapes = GetExpressionBlendShapes(CurrentExpression);
        TargetBlendShapeValues = LerpBlendShapes(TargetBlendShapeValues, ExpressionShapes, ForcedExpressionBlend);
    }
    
    // Smooth interpolation to target
    for (auto& Pair : TargetBlendShapeValues)
    {
        float* CurrentVal = CurrentBlendShapeValues.Find(Pair.Key);
        if (CurrentVal)
        {
            *CurrentVal = FMath::FInterpTo(*CurrentVal, Pair.Value, DeltaTime, (1.f - TransitionSmoothness) * 30.f);
        }
        else
        {
            CurrentBlendShapeValues.Add(Pair.Key, Pair.Value);
        }
    }
    
    // Apply to mesh
    ApplyBlendShapesToMesh(CurrentBlendShapeValues);
}

void UFELLiveLinkFaceComponent::SetExpression(EFELExpression Expression, float BlendTime)
{
    CurrentExpression = Expression;
    bForcedExpression = true;
    ForcedExpressionBlendTarget = 1.0f;
    ExpressionBlendSpeed = BlendTime > 0.f ? (1.f / BlendTime) : 10.f;
}

void UFELLiveLinkFaceComponent::ClearForcedExpression(float BlendTime)
{
    ForcedExpressionBlendTarget = 0.0f;
    ExpressionBlendSpeed = BlendTime > 0.f ? (1.f / BlendTime) : 10.f;
    // Will clear bForcedExpression when blend reaches 0
}

void UFELLiveLinkFaceComponent::BlendWithExpression(EFELExpression Expression, float BlendAlpha, float BlendTime)
{
    CurrentExpression = Expression;
    bForcedExpression = true;
    ForcedExpressionBlendTarget = FMath::Clamp(BlendAlpha, 0.f, 1.f);
    ExpressionBlendSpeed = BlendTime > 0.f ? (1.f / BlendTime) : 10.f;
}

TMap<FName, float> UFELLiveLinkFaceComponent::GetCurrentBlendShapes() const
{
    return CurrentBlendShapeValues;
}

void UFELLiveLinkFaceComponent::ApplyBlendShapesToMesh(const TMap<FName, float>& BlendShapes)
{
    if (!TargetMeshComponent) return;
    
    const int32 MaxShapes = GetBlendShapeCountForLOD(FaceRigLOD);
    int32 AppliedCount = 0;
    
    for (const auto& Pair : BlendShapes)
    {
        if (AppliedCount >= MaxShapes) break;
        
        FName MorphTargetName = Pair.Key;
        float Value = Pair.Value * FaceAnimationWeight;
        
        TargetMeshComponent->SetMorphTarget(MorphTargetName, Value);
        ++AppliedCount;
    }
}

void UFELLiveLinkFaceComponent::UpdateFallbackExpression(float DeltaTime)
{
    // Use fallback expression when no Live Link data
    TargetBlendShapeValues = GetExpressionBlendShapes(FallbackExpression);
}

void UFELLiveLinkFaceComponent::UpdateLODFromDistance()
{
    if (APlayerCameraManager* CamMgr = UGameplayStatics::GetPlayerCameraManager(this, 0))
    {
        float Distance = FVector::Dist(GetOwner()->GetActorLocation(), CamMgr->GetCameraLocation());
        
        if (Distance > MaxAnimationDistance)
        {
            FaceRigLOD = 3; // Effectively disable
        }
        else if (Distance > MaxAnimationDistance * 0.6f)
        {
            FaceRigLOD = 2;
        }
        else if (Distance > MaxAnimationDistance * 0.3f)
        {
            FaceRigLOD = 1;
        }
        else
        {
            FaceRigLOD = 0;
        }
    }
}

int32 UFELLiveLinkFaceComponent::GetBlendShapeCountForLOD(int32 LOD) const
{
    switch (LOD)
    {
        case 0: return 52;  // Full ARKit
        case 1: return 32;  // Reduced (eyes + mouth primary)
        case 2: return 16;  // Minimal (key expressions only)
        default: return 0;  // Disabled
    }
}

TMap<FName, float> UFELLiveLinkFaceComponent::GetExpressionBlendShapes(EFELExpression Expression) const
{
    TMap<FName, float> Result;
    
    switch (Expression)
    {
        case EFELExpression::Neutral:
            // All zeros - neutral face
            break;
            
        case EFELExpression::Happy:
            Result.Add(TEXT("MouthSmileLeft"), 0.8f);
            Result.Add(TEXT("MouthSmileRight"), 0.8f);
            Result.Add(TEXT("CheekSquintLeft"), 0.4f);
            Result.Add(TEXT("CheekSquintRight"), 0.4f);
            Result.Add(TEXT("EyeSquintLeft"), 0.2f);
            Result.Add(TEXT("EyeSquintRight"), 0.2f);
            Result.Add(TEXT("BrowInnerUp"), 0.1f);
            break;
            
        case EFELExpression::Determined:
            Result.Add(TEXT("BrowDownLeft"), 0.5f);
            Result.Add(TEXT("BrowDownRight"), 0.5f);
            Result.Add(TEXT("EyeSquintLeft"), 0.3f);
            Result.Add(TEXT("EyeSquintRight"), 0.3f);
            Result.Add(TEXT("JawForward"), 0.2f);
            Result.Add(TEXT("MouthPressLeft"), 0.3f);
            Result.Add(TEXT("MouthPressRight"), 0.3f);
            break;
            
        case EFELExpression::Tired:
            Result.Add(TEXT("EyeBlinkLeft"), 0.4f);
            Result.Add(TEXT("EyeBlinkRight"), 0.4f);
            Result.Add(TEXT("MouthFrownLeft"), 0.3f);
            Result.Add(TEXT("MouthFrownRight"), 0.3f);
            Result.Add(TEXT("JawOpen"), 0.3f);
            Result.Add(TEXT("BrowInnerUp"), 0.4f);
            Result.Add(TEXT("MouthShrugLower"), 0.2f);
            break;
            
        case EFELExpression::Celebrating:
            Result.Add(TEXT("MouthSmileLeft"), 1.0f);
            Result.Add(TEXT("MouthSmileRight"), 1.0f);
            Result.Add(TEXT("JawOpen"), 0.6f);
            Result.Add(TEXT("EyeWideLeft"), 0.4f);
            Result.Add(TEXT("EyeWideRight"), 0.4f);
            Result.Add(TEXT("BrowOuterUpLeft"), 0.5f);
            Result.Add(TEXT("BrowOuterUpRight"), 0.5f);
            Result.Add(TEXT("BrowInnerUp"), 0.6f);
            Result.Add(TEXT("CheekSquintLeft"), 0.5f);
            Result.Add(TEXT("CheekSquintRight"), 0.5f);
            break;
            
        case EFELExpression::Disappointed:
            Result.Add(TEXT("MouthFrownLeft"), 0.6f);
            Result.Add(TEXT("MouthFrownRight"), 0.6f);
            Result.Add(TEXT("BrowInnerUp"), 0.5f);
            Result.Add(TEXT("BrowDownLeft"), 0.2f);
            Result.Add(TEXT("BrowDownRight"), 0.2f);
            Result.Add(TEXT("EyeLookDownLeft"), 0.3f);
            Result.Add(TEXT("EyeLookDownRight"), 0.3f);
            Result.Add(TEXT("MouthShrugLower"), 0.3f);
            break;
            
        case EFELExpression::Angry:
            Result.Add(TEXT("BrowDownLeft"), 0.8f);
            Result.Add(TEXT("BrowDownRight"), 0.8f);
            Result.Add(TEXT("EyeSquintLeft"), 0.5f);
            Result.Add(TEXT("EyeSquintRight"), 0.5f);
            Result.Add(TEXT("NoseSneerLeft"), 0.6f);
            Result.Add(TEXT("NoseSneerRight"), 0.6f);
            Result.Add(TEXT("MouthFrownLeft"), 0.4f);
            Result.Add(TEXT("MouthFrownRight"), 0.4f);
            Result.Add(TEXT("JawForward"), 0.3f);
            break;
            
        case EFELExpression::Surprised:
            Result.Add(TEXT("EyeWideLeft"), 0.8f);
            Result.Add(TEXT("EyeWideRight"), 0.8f);
            Result.Add(TEXT("BrowInnerUp"), 0.8f);
            Result.Add(TEXT("BrowOuterUpLeft"), 0.7f);
            Result.Add(TEXT("BrowOuterUpRight"), 0.7f);
            Result.Add(TEXT("JawOpen"), 0.5f);
            Result.Add(TEXT("MouthFunnel"), 0.3f);
            break;
            
        case EFELExpression::Talking_A:
            Result.Add(TEXT("JawOpen"), 0.7f);
            Result.Add(TEXT("MouthFunnel"), 0.1f);
            break;
            
        case EFELExpression::Talking_E:
            Result.Add(TEXT("JawOpen"), 0.3f);
            Result.Add(TEXT("MouthSmileLeft"), 0.4f);
            Result.Add(TEXT("MouthSmileRight"), 0.4f);
            Result.Add(TEXT("MouthStretchLeft"), 0.3f);
            Result.Add(TEXT("MouthStretchRight"), 0.3f);
            break;
            
        case EFELExpression::Talking_O:
            Result.Add(TEXT("JawOpen"), 0.5f);
            Result.Add(TEXT("MouthFunnel"), 0.6f);
            Result.Add(TEXT("MouthPucker"), 0.3f);
            break;
            
        case EFELExpression::Talking_U:
            Result.Add(TEXT("JawOpen"), 0.2f);
            Result.Add(TEXT("MouthPucker"), 0.7f);
            Result.Add(TEXT("MouthFunnel"), 0.4f);
            break;
            
        case EFELExpression::TrashTalk:
            Result.Add(TEXT("MouthSmileLeft"), 0.7f);
            Result.Add(TEXT("MouthSmileRight"), 0.2f);
            Result.Add(TEXT("BrowDownLeft"), 0.3f);
            Result.Add(TEXT("EyeSquintLeft"), 0.2f);
            Result.Add(TEXT("NoseSneerLeft"), 0.3f);
            Result.Add(TEXT("CheekSquintLeft"), 0.3f);
            break;
            
        case EFELExpression::Pain:
            Result.Add(TEXT("BrowDownLeft"), 0.6f);
            Result.Add(TEXT("BrowDownRight"), 0.6f);
            Result.Add(TEXT("BrowInnerUp"), 0.7f);
            Result.Add(TEXT("EyeSquintLeft"), 0.7f);
            Result.Add(TEXT("EyeSquintRight"), 0.7f);
            Result.Add(TEXT("NoseSneerLeft"), 0.5f);
            Result.Add(TEXT("NoseSneerRight"), 0.5f);
            Result.Add(TEXT("MouthStretchLeft"), 0.4f);
            Result.Add(TEXT("MouthStretchRight"), 0.4f);
            Result.Add(TEXT("JawOpen"), 0.2f);
            break;
            
        case EFELExpression::Recovery:
            Result.Add(TEXT("JawOpen"), 0.4f);
            Result.Add(TEXT("MouthSmileLeft"), 0.3f);
            Result.Add(TEXT("MouthSmileRight"), 0.3f);
            Result.Add(TEXT("BrowInnerUp"), 0.2f);
            Result.Add(TEXT("EyeBlinkLeft"), 0.2f);
            Result.Add(TEXT("EyeBlinkRight"), 0.2f);
            break;
    }
    
    return Result;
}

TMap<FName, float> UFELLiveLinkFaceComponent::LerpBlendShapes(
    const TMap<FName, float>& A, const TMap<FName, float>& B, float Alpha) const
{
    TMap<FName, float> Result = A;
    
    for (const auto& Pair : B)
    {
        if (float* ExistingVal = Result.Find(Pair.Key))
        {
            *ExistingVal = FMath::Lerp(*ExistingVal, Pair.Value, Alpha);
        }
        else
        {
            Result.Add(Pair.Key, Pair.Value * Alpha);
        }
    }
    
    return Result;
}
