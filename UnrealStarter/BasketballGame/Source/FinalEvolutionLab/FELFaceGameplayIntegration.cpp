// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: Gameplay Integration Implementation

#include "FELFaceGameplayIntegration.h"
#include "FELExpressionTrigger.h"
#include "FELLiveLinkFaceComponent.h"
#include "GameFramework/Character.h"
#include "Kismet/GameplayStatics.h"
#include "EngineUtils.h"

DEFINE_LOG_CATEGORY(LogFELFaceGameplay);

void UFELFaceGameplayIntegration::Initialize(FSubsystemCollectionBase& Collection)
{
    Super::Initialize(Collection);
    SetupGameModeConfigs();
    UE_LOG(LogFELFaceGameplay, Log, TEXT("Face Gameplay Integration initialized with %d game mode configs."), GameModeConfigs.Num());
}

void UFELFaceGameplayIntegration::SetupGameModeConfigs()
{
    // Basketball modes
    auto AddConfig = [this](const FString& Id, EFELExpression Idle, EFELExpression Active, float Intensity, bool NPCFace, int32 MaxNPC)
    {
        FFELFaceGameModeConfig Config;
        Config.GameModeId = Id;
        Config.IdleExpression = Idle;
        Config.ActiveExpression = Active;
        Config.ExpressionIntensity = Intensity;
        Config.bNPCFacialAnimation = NPCFace;
        Config.MaxAnimatedNPCs = MaxNPC;
        GameModeConfigs.Add(Id, Config);
    };

    // 17 Game Modes
    AddConfig(TEXT("basketball_h2h"),       EFELExpression::Determined, EFELExpression::Determined, 1.0f, true, 4);
    AddConfig(TEXT("basketball_3v3"),       EFELExpression::Determined, EFELExpression::Determined, 1.0f, true, 6);
    AddConfig(TEXT("basketball_tournament"),EFELExpression::Determined, EFELExpression::Determined, 1.2f, true, 8);
    AddConfig(TEXT("basketball_practice"),  EFELExpression::Neutral,    EFELExpression::Determined, 0.8f, false, 0);
    AddConfig(TEXT("soccer"),               EFELExpression::Determined, EFELExpression::Determined, 1.0f, true, 6);
    AddConfig(TEXT("football"),             EFELExpression::Determined, EFELExpression::Angry,      1.1f, true, 6);
    AddConfig(TEXT("boxing_h2h"),           EFELExpression::Angry,      EFELExpression::Angry,      1.3f, true, 2);
    AddConfig(TEXT("mma_h2h"),              EFELExpression::Angry,      EFELExpression::Angry,      1.3f, true, 2);
    AddConfig(TEXT("tennis"),               EFELExpression::Determined, EFELExpression::Determined, 0.9f, true, 2);
    AddConfig(TEXT("volleyball"),           EFELExpression::Happy,      EFELExpression::Determined, 1.0f, true, 6);
    AddConfig(TEXT("baseball"),             EFELExpression::Determined, EFELExpression::Determined, 1.0f, true, 4);
    AddConfig(TEXT("track_field"),          EFELExpression::Determined, EFELExpression::Pain,       1.1f, true, 4);
    AddConfig(TEXT("swimming"),             EFELExpression::Determined, EFELExpression::Pain,       1.0f, false, 0);
    AddConfig(TEXT("gymnastics"),           EFELExpression::Determined, EFELExpression::Determined, 1.0f, true, 2);
    AddConfig(TEXT("skateboarding"),        EFELExpression::Happy,      EFELExpression::Determined, 0.9f, true, 4);
    AddConfig(TEXT("workout"),              EFELExpression::Neutral,    EFELExpression::Pain,       1.0f, false, 0);
    AddConfig(TEXT("karate_h2h"),           EFELExpression::Determined, EFELExpression::Angry,      1.2f, true, 2);
}

void UFELFaceGameplayIntegration::OnGameModeStarted(const FString& GameModeId)
{
    CurrentGameModeId = GameModeId;
    
    if (const FFELFaceGameModeConfig* Config = GameModeConfigs.Find(GameModeId))
    {
        UE_LOG(LogFELFaceGameplay, Log, TEXT("Game mode started: %s (Intensity=%.1f, NPCFace=%s)"),
            *GameModeId, Config->ExpressionIntensity, Config->bNPCFacialAnimation ? TEXT("ON") : TEXT("OFF"));
    }
}

void UFELFaceGameplayIntegration::OnGameModeEnded()
{
    UE_LOG(LogFELFaceGameplay, Log, TEXT("Game mode ended: %s"), *CurrentGameModeId);
    CurrentGameModeId.Empty();
}

FFELFaceGameModeConfig UFELFaceGameplayIntegration::GetGameModeConfig(const FString& GameModeId) const
{
    if (const FFELFaceGameModeConfig* Config = GameModeConfigs.Find(GameModeId))
    {
        return *Config;
    }
    return FFELFaceGameModeConfig();
}

// --- Gameplay Events ---

void UFELFaceGameplayIntegration::OnPlayerScored() { TriggerEventForPlayer(EFELGameplayEvent::ScoreBasket); TriggerCrowdCelebration(); }
void UFELFaceGameplayIntegration::OnPlayerMissed() { TriggerEventForPlayer(EFELGameplayEvent::MissShot); }
void UFELFaceGameplayIntegration::OnPlayerBlocked() { TriggerEventForPlayer(EFELGameplayEvent::GetBlocked); }
void UFELFaceGameplayIntegration::OnGameWon() { TriggerEventForPlayer(EFELGameplayEvent::WinGame); TriggerCrowdCelebration(); }
void UFELFaceGameplayIntegration::OnGameLost() { TriggerEventForPlayer(EFELGameplayEvent::LoseGame); TriggerCrowdDisappointment(); }

// --- Workout Events ---

void UFELFaceGameplayIntegration::OnExerciseStarted() { TriggerEventForPlayer(EFELGameplayEvent::StartExercise); }
void UFELFaceGameplayIntegration::OnMaxEffort() { TriggerEventForPlayer(EFELGameplayEvent::MaxEffort); }
void UFELFaceGameplayIntegration::OnExerciseCompleted() { TriggerEventForPlayer(EFELGameplayEvent::CompleteWorkout); }
void UFELFaceGameplayIntegration::OnExerciseFailed() { TriggerEventForPlayer(EFELGameplayEvent::FailExercise); }
void UFELFaceGameplayIntegration::OnRecovery() { TriggerEventForPlayer(EFELGameplayEvent::Recovery); }

// --- Cutscene Events ---

void UFELFaceGameplayIntegration::OnCutsceneDialogue(AActor* Speaker)
{
    if (UFELExpressionTriggerSubsystem* TriggerSys = GetGameInstance()->GetSubsystem<UFELExpressionTriggerSubsystem>())
    {
        TriggerSys->TriggerExpression(Speaker, EFELGameplayEvent::CutsceneDialogue);
    }
}

void UFELFaceGameplayIntegration::OnCutsceneReaction(AActor* Reactor, EFELExpression ReactionExpression)
{
    if (UFELLiveLinkFaceComponent* FaceComp = Reactor->FindComponentByClass<UFELLiveLinkFaceComponent>())
    {
        FaceComp->SetExpression(ReactionExpression, 0.3f);
    }
}

void UFELFaceGameplayIntegration::OnCutsceneEnded()
{
    // Clear all forced expressions
    if (UWorld* World = GetWorld())
    {
        for (TActorIterator<AActor> It(World); It; ++It)
        {
            if (UFELLiveLinkFaceComponent* FaceComp = It->FindComponentByClass<UFELLiveLinkFaceComponent>())
            {
                FaceComp->ClearForcedExpression(0.5f);
            }
        }
    }
}

// --- Crowd ---

void UFELFaceGameplayIntegration::TriggerCrowdCelebration()
{
    if (UWorld* World = GetWorld())
    {
        const FFELFaceGameModeConfig* Config = GameModeConfigs.Find(CurrentGameModeId);
        int32 MaxNPC = Config ? Config->MaxAnimatedNPCs : 4;
        int32 Count = 0;
        
        for (TActorIterator<AActor> It(World); It; ++It)
        {
            if (Count >= MaxNPC) break;
            if (UFELLiveLinkFaceComponent* FaceComp = It->FindComponentByClass<UFELLiveLinkFaceComponent>())
            {
                if (FaceComp->CharacterType == EFELCharacterType::NPC_TypeB)
                {
                    FaceComp->SetExpression(EFELExpression::Celebrating, 0.2f);
                    ++Count;
                }
            }
        }
    }
}

void UFELFaceGameplayIntegration::TriggerCrowdDisappointment()
{
    if (UWorld* World = GetWorld())
    {
        for (TActorIterator<AActor> It(World); It; ++It)
        {
            if (UFELLiveLinkFaceComponent* FaceComp = It->FindComponentByClass<UFELLiveLinkFaceComponent>())
            {
                if (FaceComp->CharacterType == EFELCharacterType::NPC_TypeB)
                {
                    FaceComp->SetExpression(EFELExpression::Disappointed, 0.3f);
                }
            }
        }
    }
}

void UFELFaceGameplayIntegration::SetCrowdIdle()
{
    if (UWorld* World = GetWorld())
    {
        for (TActorIterator<AActor> It(World); It; ++It)
        {
            if (UFELLiveLinkFaceComponent* FaceComp = It->FindComponentByClass<UFELLiveLinkFaceComponent>())
            {
                if (FaceComp->CharacterType == EFELCharacterType::NPC_TypeB ||
                    FaceComp->CharacterType == EFELCharacterType::NPC_TypeC)
                {
                    FaceComp->ClearForcedExpression(0.5f);
                }
            }
        }
    }
}

void UFELFaceGameplayIntegration::TriggerEventForPlayer(EFELGameplayEvent Event)
{
    if (UFELExpressionTriggerSubsystem* TriggerSys = GetGameInstance()->GetSubsystem<UFELExpressionTriggerSubsystem>())
    {
        TriggerSys->TriggerPlayerExpression(Event);
    }
}
