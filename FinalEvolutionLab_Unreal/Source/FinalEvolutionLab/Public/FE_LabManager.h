#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FinalEvolutionTypes.h"
#include "FE_LabManager.generated.h"

class AArenaActor;

UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API AFE_LabManager : public AActor
{
    GENERATED_BODY()

public:
    AFE_LabManager();

    UFUNCTION(BlueprintCallable, Category = "Lab")
    void SetGameMode(EGameModeId NewMode);

    UFUNCTION(BlueprintCallable, Category = "Lab")
    void StartLabSession();

    UFUNCTION(BlueprintCallable, Category = "Lab")
    void SyncFromGameInstance();

    UPROPERTY(BlueprintReadOnly, Category = "Lab")
    EGameModeId CurrentMode = EGameModeId::BASKETBALL_HEAD_TO_HEAD;

    UPROPERTY(BlueprintReadOnly, Category = "Lab")
    int32 CurrentShards = 0;

    UPROPERTY(BlueprintReadOnly, Category = "Lab")
    float CurrentPRQ = 50.0f;

    UPROPERTY(BlueprintReadOnly, Category = "Lab")
    FGameAttributes CurrentAttributes;

protected:
    virtual void BeginPlay() override;

private:
    UPROPERTY(EditAnywhere, Category = "Lab")
    bool bApplyArenaThemeOnBeginPlay = true;

    UPROPERTY(EditAnywhere, Category = "Lab")
    TObjectPtr<AArenaActor> ArenaActor;
};
