#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "RorkNativeBridgeComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnInternalPrqUpdated, int32, Score);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnNativePrqUpdated, int32, Score);

UCLASS(ClassGroup=(Rork), BlueprintType, Blueprintable, meta=(BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API URorkNativeBridgeComponent : public UActorComponent
{
    GENERATED_BODY()

public:
    URorkNativeBridgeComponent();

    UFUNCTION(BlueprintCallable, Category = "Rork|Bridge")
    void PostRorkScoreToNative(int32 Score);

    UFUNCTION(BlueprintCallable, Category = "Rork|Bridge")
    void OnRorkScoreUpdated(int32 Score);

    UFUNCTION(BlueprintCallable, Category = "Rork|Bridge")
    void UpdateInternalPRQDisplayPublic();

    // Legacy alias kept for parity with prior Unity-facing naming.
    UFUNCTION(BlueprintCallable, Category = "Rork|Bridge")
    void UpdateUnityPRQDisplayPublic();

    UFUNCTION(BlueprintPure, Category = "Rork|Bridge")
    int32 GetCurrentInternalPrq() const { return CurrentInternalPrq; }

    UPROPERTY(BlueprintAssignable, Category = "Rork|Bridge")
    FOnInternalPrqUpdated OnInternalPrqUpdated;

    UPROPERTY(BlueprintAssignable, Category = "Rork|Bridge")
    FOnNativePrqUpdated OnNativePrqUpdated;

protected:
    virtual void BeginPlay() override;

private:
    UPROPERTY(VisibleAnywhere, Category = "Rork|Bridge")
    int32 CurrentInternalPrq = 0;
};
