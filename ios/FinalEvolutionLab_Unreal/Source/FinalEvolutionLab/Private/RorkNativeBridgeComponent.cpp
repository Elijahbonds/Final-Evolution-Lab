#include "RorkNativeBridgeComponent.h"

#include "PlayerScoreManager.h"

#if PLATFORM_IOS && !WITH_EDITOR
extern "C" void _PostRorkScore(int32 Score);
#endif

URorkNativeBridgeComponent::URorkNativeBridgeComponent()
{
    PrimaryComponentTick.bCanEverTick = false;
}

void URorkNativeBridgeComponent::BeginPlay()
{
    Super::BeginPlay();
    UpdateInternalPRQDisplayPublic();
    UE_LOG(LogTemp, Log, TEXT("[RorkNativeBridge] Initialized."));
}

void URorkNativeBridgeComponent::PostRorkScoreToNative(int32 Score)
{
    UE_LOG(LogTemp, Log, TEXT("[RorkNativeBridge] Sending PRQ score %d to native iOS."), Score);

    CurrentInternalPrq = Score;
    OnInternalPrqUpdated.Broadcast(CurrentInternalPrq);

#if PLATFORM_IOS && !WITH_EDITOR
    _PostRorkScore(Score);
#else
    UE_LOG(LogTemp, Warning, TEXT("[RorkNativeBridge] _PostRorkScore outside iOS build. Simulating callback."));
    OnRorkScoreUpdated(Score);
#endif
}

void URorkNativeBridgeComponent::OnRorkScoreUpdated(int32 Score)
{
    UE_LOG(LogTemp, Log, TEXT("[RorkNativeBridge] Received PRQ score from native: %d"), Score);
    OnNativePrqUpdated.Broadcast(Score);
}

void URorkNativeBridgeComponent::UpdateInternalPRQDisplayPublic()
{
    if (APlayerScoreManager* ScoreManager = APlayerScoreManager::Get(this))
    {
        CurrentInternalPrq = ScoreManager->GetPlayerScore();
    }

    OnInternalPrqUpdated.Broadcast(CurrentInternalPrq);
}

void URorkNativeBridgeComponent::UpdateUnityPRQDisplayPublic()
{
    UpdateInternalPRQDisplayPublic();
}
