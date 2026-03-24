#pragma once

#include "CoreMinimal.h"
#include "Engine/GameInstance.h"
#include "FinalEvolutionTypes.h"
#include "FE_GameInstance.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFE_GameInstance : public UGameInstance
{
    GENERATED_BODY()

public:
    UFE_GameInstance();

    UPROPERTY(BlueprintReadWrite, Category = "Player State")
    int32 EvolutionShards;

    UPROPERTY(BlueprintReadWrite, Category = "Player State")
    float PRQScore;

    UPROPERTY(BlueprintReadWrite, Category = "Player State")
    int32 StreakDays;

    UPROPERTY(BlueprintReadWrite, Category = "Attributes")
    FGameAttributes PlayerAttributes;

    UFUNCTION(BlueprintCallable, Category = "Economy")
    bool SpendShards(int32 Amount);

    UFUNCTION(BlueprintCallable, Category = "Save")
    bool SavePlayerState();

    UFUNCTION(BlueprintCallable, Category = "Save")
    bool LoadPlayerState();

private:
    UPROPERTY(EditDefaultsOnly, Category = "Save")
    FString SaveSlotName = TEXT("FinalEvolution_PlayerState");

    UPROPERTY(EditDefaultsOnly, Category = "Save")
    int32 SaveUserIndex = 0;
};
