// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: Expression Trigger System Implementation

#include "FELExpressionTrigger.h"
#include "FELLiveLinkFaceComponent.h"
#include "GameFramework/Character.h"
#include "Kismet/GameplayStatics.h"

DEFINE_LOG_CATEGORY(LogFELExprTrigger);

void UFELExpressionTriggerSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
    Super::Initialize(Collection);
    SetupDefaultTriggers();
    UE_LOG(LogFELExprTrigger, Log, TEXT("Expression Trigger subsystem initialized with %d triggers."), EventTriggerMap.Num());
}

void UFELExpressionTriggerSubsystem::Deinitialize()
{
    EventTriggerMap.Empty();
    Super::Deinitialize();
}

void UFELExpressionTriggerSubsystem::SetupDefaultTriggers()
{
    // Basketball events
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::ScoreBasket;    T.Expression = EFELExpression::Celebrating;   T.Duration = 3.0f; T.BlendInTime = 0.15f; T.BlendOutTime = 0.5f; T.Priority = 5;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::MissShot;       T.Expression = EFELExpression::Disappointed;   T.Duration = 2.0f; T.BlendInTime = 0.2f;  T.BlendOutTime = 0.4f; T.Priority = 3;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::GetBlocked;     T.Expression = EFELExpression::Angry;          T.Duration = 1.5f; T.BlendInTime = 0.1f;  T.BlendOutTime = 0.3f; T.Priority = 4;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::BlockOpponent;  T.Expression = EFELExpression::Celebrating;    T.Duration = 2.0f; T.BlendInTime = 0.15f; T.BlendOutTime = 0.4f; T.Priority = 4;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::Steal;          T.Expression = EFELExpression::Happy;          T.Duration = 1.5f; T.BlendInTime = 0.1f;  T.BlendOutTime = 0.3f; T.Priority = 3;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::GetStolen;      T.Expression = EFELExpression::Surprised;      T.Duration = 1.0f; T.BlendInTime = 0.05f; T.BlendOutTime = 0.3f; T.Priority = 3;  EventTriggerMap.Add(T.Event, T); }
    
    // Game outcome events
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::WinGame;        T.Expression = EFELExpression::Celebrating;    T.Duration = 5.0f; T.BlendInTime = 0.2f;  T.BlendOutTime = 1.0f; T.Priority = 10; EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::LoseGame;       T.Expression = EFELExpression::Disappointed;   T.Duration = 4.0f; T.BlendInTime = 0.3f;  T.BlendOutTime = 0.8f; T.Priority = 10; EventTriggerMap.Add(T.Event, T); }
    
    // Workout events
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::CompleteWorkout;T.Expression = EFELExpression::Recovery;       T.Duration = 3.0f; T.BlendInTime = 0.3f;  T.BlendOutTime = 0.6f; T.Priority = 6;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::FailExercise;   T.Expression = EFELExpression::Disappointed;   T.Duration = 2.0f; T.BlendInTime = 0.2f;  T.BlendOutTime = 0.5f; T.Priority = 5;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::StartExercise;  T.Expression = EFELExpression::Determined;     T.Duration = 2.0f; T.BlendInTime = 0.3f;  T.BlendOutTime = 0.4f; T.Priority = 2;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::MaxEffort;      T.Expression = EFELExpression::Pain;           T.Duration = 1.5f; T.BlendInTime = 0.1f;  T.BlendOutTime = 0.5f; T.Priority = 7;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::Recovery;       T.Expression = EFELExpression::Recovery;       T.Duration = 3.0f; T.BlendInTime = 0.4f;  T.BlendOutTime = 0.6f; T.Priority = 2;  EventTriggerMap.Add(T.Event, T); }
    
    // Social events
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::Taunt;          T.Expression = EFELExpression::TrashTalk;      T.Duration = 2.5f; T.BlendInTime = 0.2f;  T.BlendOutTime = 0.3f; T.Priority = 4;  EventTriggerMap.Add(T.Event, T); }
    
    // Cutscene events
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::CutsceneDialogue;T.Expression = EFELExpression::Talking_A;    T.Duration = 0.5f; T.BlendInTime = 0.1f;  T.BlendOutTime = 0.1f; T.Priority = 8;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::CutsceneReaction;T.Expression = EFELExpression::Surprised;    T.Duration = 2.0f; T.BlendInTime = 0.1f;  T.BlendOutTime = 0.4f; T.Priority = 8;  EventTriggerMap.Add(T.Event, T); }
    
    // Multi-sport events
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::ScoreGoal;      T.Expression = EFELExpression::Celebrating;    T.Duration = 4.0f; T.BlendInTime = 0.15f; T.BlendOutTime = 0.6f; T.Priority = 6;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::KnockOut;       T.Expression = EFELExpression::Celebrating;    T.Duration = 5.0f; T.BlendInTime = 0.1f;  T.BlendOutTime = 0.8f; T.Priority = 9;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::PerfectLanding; T.Expression = EFELExpression::Happy;          T.Duration = 2.0f; T.BlendInTime = 0.2f;  T.BlendOutTime = 0.4f; T.Priority = 5;  EventTriggerMap.Add(T.Event, T); }
    { FFELExpressionTrigger T; T.Event = EFELGameplayEvent::FoulCommitted;  T.Expression = EFELExpression::Angry;          T.Duration = 2.0f; T.BlendInTime = 0.1f;  T.BlendOutTime = 0.4f; T.Priority = 4;  EventTriggerMap.Add(T.Event, T); }
}

void UFELExpressionTriggerSubsystem::TriggerExpression(AActor* TargetActor, EFELGameplayEvent Event)
{
    if (!TargetActor) return;
    
    if (const FFELExpressionTrigger* Trigger = EventTriggerMap.Find(Event))
    {
        ApplyExpressionToActor(TargetActor, *Trigger);
        UE_LOG(LogFELExprTrigger, Verbose, TEXT("Triggered expression %d on %s for event %d"),
            (int32)Trigger->Expression, *TargetActor->GetName(), (int32)Event);
    }
}

void UFELExpressionTriggerSubsystem::TriggerExpressionAll(EFELGameplayEvent Event)
{
    if (UWorld* World = GetWorld())
    {
        for (TActorIterator<AActor> It(World); It; ++It)
        {
            if (It->FindComponentByClass<UFELLiveLinkFaceComponent>())
            {
                TriggerExpression(*It, Event);
            }
        }
    }
}

void UFELExpressionTriggerSubsystem::TriggerPlayerExpression(EFELGameplayEvent Event)
{
    if (UWorld* World = GetWorld())
    {
        if (ACharacter* PlayerChar = UGameplayStatics::GetPlayerCharacter(World, 0))
        {
            TriggerExpression(PlayerChar, Event);
        }
    }
}

void UFELExpressionTriggerSubsystem::RegisterTrigger(EFELGameplayEvent Event, const FFELExpressionTrigger& Trigger)
{
    EventTriggerMap.Add(Event, Trigger);
}

FFELExpressionTrigger UFELExpressionTriggerSubsystem::GetTriggerForEvent(EFELGameplayEvent Event) const
{
    if (const FFELExpressionTrigger* Trigger = EventTriggerMap.Find(Event))
    {
        return *Trigger;
    }
    return FFELExpressionTrigger();
}

void UFELExpressionTriggerSubsystem::ApplyExpressionToActor(AActor* Actor, const FFELExpressionTrigger& Trigger)
{
    if (UFELLiveLinkFaceComponent* FaceComp = Actor->FindComponentByClass<UFELLiveLinkFaceComponent>())
    {
        FaceComp->SetExpression(Trigger.Expression, Trigger.BlendInTime);
        
        // Set timer to clear expression after duration
        if (UWorld* World = GetWorld())
        {
            FTimerHandle ClearTimer;
            float Duration = Trigger.Duration;
            float BlendOut = Trigger.BlendOutTime;
            TWeakObjectPtr<UFELLiveLinkFaceComponent> WeakComp(FaceComp);
            
            World->GetTimerManager().SetTimer(ClearTimer, [WeakComp, BlendOut]()
            {
                if (WeakComp.IsValid())
                {
                    WeakComp->ClearForcedExpression(BlendOut);
                }
            }, Duration, false);
        }
    }
}
