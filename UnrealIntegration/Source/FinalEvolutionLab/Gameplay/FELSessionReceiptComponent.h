// FELSessionReceiptComponent.h
// Phase 7 — Session Receipt + Economy Broadcast Component
// Attach to any APawn participating in a FEL match

#pragma once
#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FELGameplayManager.h"
#include "FELSessionReceiptComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FFELRewardReadyDelegate, int32, XPEarned, int32, ShardsEarned);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FFELPRQUpdateDelegate, float, PRQDelta);

UCLASS(ClassGroup=(FEL), meta=(BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELSessionReceiptComponent : public UActorComponent {
    GENERATED_BODY()
public:
    UFELSessionReceiptComponent();

    // Broadcast when reward computation is complete — wires to HUD_ShardCounter + HUD_PRQMeter
    UPROPERTY(BlueprintAssignable, Category="FEL|Economy")
    FFELRewardReadyDelegate OnRewardReady;

    UPROPERTY(BlueprintAssignable, Category="FEL|Economy")
    FFELPRQUpdateDelegate OnPRQUpdate;

    // Called by GameMode after match ends
    UFUNCTION(BlueprintCallable, Category="FEL|Economy")
    void ProcessMatchResult(const FFELSessionResult& Result);

    // Deep-link payload for WBP_MatchResult widget
    UFUNCTION(BlueprintPure, Category="FEL|Economy")
    FString BuildMatchResultDeepLink(const FFELSessionResult& Result) const;

    // Broadcast HUD update via WebSocket relay
    UFUNCTION(BlueprintCallable, Category="FEL|HUD")
    void BroadcastEconomyHUDUpdate(int32 NewShards, int32 NewXP, float NewPRQ);

private:
    UPROPERTY() UFELGameplayManager* GameplayMgr;
    virtual void BeginPlay() override;
};
