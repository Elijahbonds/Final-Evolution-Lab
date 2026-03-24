#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "FinalEvolutionTypes.h"
#include "FE_CoachingPortalWidget.generated.h"

UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API UFE_CoachingPortalWidget : public UUserWidget
{
    GENERATED_BODY()

public:
    UFUNCTION(BlueprintCallable, Category = "Portal")
    void RefreshFromGameInstance();

    UFUNCTION(BlueprintCallable, Category = "Portal")
    bool SpendShardsFromPortal(int32 Amount);

    UFUNCTION(BlueprintCallable, Category = "Portal")
    void ApplySessionReward(int32 ShardReward, float PRQDelta);

    UPROPERTY(BlueprintReadOnly, Category = "Portal")
    int32 DisplayShards = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Portal")
    float DisplayPRQ = 50.0f;

    UPROPERTY(BlueprintReadOnly, Category = "Portal")
    FGameAttributes DisplayAttributes;

    UFUNCTION(BlueprintImplementableEvent, Category = "Portal")
    void OnPortalStateUpdated();
};
