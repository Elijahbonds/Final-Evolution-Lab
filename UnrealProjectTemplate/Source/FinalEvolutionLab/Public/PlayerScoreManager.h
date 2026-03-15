#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "PlayerScoreManager.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnPlayerScoreUpdated, int32, NewScore);

UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API APlayerScoreManager : public AActor
{
    GENERATED_BODY()

public:
    APlayerScoreManager();

    UFUNCTION(BlueprintPure, Category = "Rork|Score")
    int32 GetPlayerScore() const;

    UFUNCTION(BlueprintCallable, Category = "Rork|Score")
    void UpdatePlayerScore(int32 NewScore);

    UFUNCTION(BlueprintPure, Category = "Rork|Score")
    static APlayerScoreManager* Get(UObject* WorldContextObject);

    UPROPERTY(BlueprintAssignable, Category = "Rork|Score")
    FOnPlayerScoreUpdated OnPlayerScoreUpdated;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

private:
    UPROPERTY(EditAnywhere, Category = "Rork|Score")
    int32 Score = 0;

    static TWeakObjectPtr<APlayerScoreManager> Instance;
};
